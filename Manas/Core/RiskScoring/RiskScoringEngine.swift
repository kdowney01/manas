import Foundation
import Combine
import OSLog

private let log = Logger(subsystem: "com.manas.app", category: "RiskScoring")

@MainActor
final class RiskScoringEngine: ObservableObject {
    @Published var currentRisk: RiskSeverity = .low
    @Published var currentScore: Double = 0.0
    @Published var recentEvents: [RiskEvent] = []
    @Published var userProfile = UserProfile()
    @Published private(set) var latestSnapshot: BiometricSnapshot?

    /// How the Overall wellbeing score combines Physio + Digital. UI preference
    /// (not PHI), so UserDefaults-backed persistence is acceptable here.
    @Published var scoreMethod: ScoreMethod = {
        let raw = UserDefaults.standard.string(forKey: "overallScoreMethod") ?? ""
        return ScoreMethod(rawValue: raw) ?? .lowestPullsDown
    }() {
        didSet { UserDefaults.standard.set(scoreMethod.rawValue, forKey: "overallScoreMethod") }
    }

    private var snapshotHistory: [BiometricSnapshot] = []
    private let alertManager = AlertManager.shared
    private let backend = BackendService.shared

    func process(_ snapshot: BiometricSnapshot) {
        snapshotHistory.append(snapshot)
        if snapshotHistory.count > 7 * 24 { snapshotHistory.removeFirst() }
        latestSnapshot = snapshot

        if !userProfile.calibrationComplete {
            userProfile.calibrationSampleCount += 1
            if userProfile.calibrationSampleCount >= UserProfile.calibrationTargetSamples {
                userProfile.finalizeCalibration(snapshots: snapshotHistory)
                log.info("Calibration complete — risk scoring now active")
            }
            return
        }

        let score = computeScore(snapshot)
        let newRisk = severity(for: score)

        // Only emit an event on risk level change (avoid event spam)
        let riskChanged = newRisk != currentRisk

        currentScore = score
        currentRisk = newRisk

        if riskChanged && newRisk >= .high {
            let event = RiskEvent(
                severity: newRisk,
                triggerSignals: activeTriggers(snapshot),
                riskScore: score
            )
            recentEvents.insert(event, at: 0)
            if recentEvents.count > 50 { recentEvents.removeLast() }

            // Fire local notification + crisis flow
            alertManager.handle(event: event)

            // Report to backend (async, best-effort — never blocks UI)
            Task { await backend.reportRiskEvent(event) }

            // HIPAA: log severity only, not the raw score or signal values
            log.info("Risk event: severity=\(newRisk.rawValue, privacy: .public)")
        }

        // Send telemetry (derived stress index, not raw readings)
        Task { await backend.sendTelemetry(snapshot) }
    }

    // MARK: - Scoring
    // Weighted sum across four signal categories.
    // Weights are grounded in the MAANAS rPPG physiological homeostasis logic.

    private func computeScore(_ s: BiometricSnapshot) -> Double {
        var score = 0.0
        let t = userProfile.riskThresholds

        // HRV (weight 0.40) — suppressed HRV is the strongest stress marker
        if let hrv = s.hrv {
            if hrv < t.criticalHRV { score += 0.40 }
            else if hrv < t.lowHRV  { score += 0.20 }
        }

        // Heart rate (weight 0.30)
        if let hr = s.heartRate {
            if hr > t.highHR * 1.15 { score += 0.30 }
            else if hr > t.highHR   { score += 0.15 }
        }

        // Sleep (weight 0.20)
        if let sleep = s.sleepHours {
            if sleep < t.minSleepHours * 0.75 { score += 0.20 }
            else if sleep < t.minSleepHours   { score += 0.10 }
        }

        // Activity anomaly (weight 0.10)
        if let steps = s.stepCount, let avg = recentStepAverage(), avg > 0 {
            let ratio = Double(steps) / avg
            if ratio < 0.30      { score += 0.10 }
            else if ratio < 0.50 { score += 0.05 }
        }

        // Facial emotion stress signal (weight 0.15 when available)
        // Replaces 0.05 from activity signal when face data present.
        if let emotion = s.emotionVector {
            let emotionStress = Double(emotion.stressSignal)
            if emotionStress > 0.6      { score += 0.15 }
            else if emotionStress > 0.3 { score += 0.08 }
        }

        return min(score, 1.0)
    }

    private func severity(for score: Double) -> RiskSeverity {
        switch score {
        case 0.75...: return .crisis
        case 0.50...: return .high
        case 0.25...: return .moderate
        default:      return .low
        }
    }

    private func activeTriggers(_ s: BiometricSnapshot) -> [String] {
        var triggers: [String] = []
        let t = userProfile.riskThresholds
        // HIPAA: trigger labels describe the signal, not the raw value
        if let hrv = s.hrv,    hrv < t.lowHRV    { triggers.append("Low HRV") }
        if let hr  = s.heartRate, hr > t.highHR   { triggers.append("Elevated heart rate") }
        if let sl  = s.sleepHours, sl < t.minSleepHours { triggers.append("Insufficient sleep") }
        return triggers
    }

    private func recentStepAverage() -> Double? {
        let recent = snapshotHistory.suffix(7).compactMap(\.stepCount)
        guard !recent.isEmpty else { return nil }
        return Double(recent.reduce(0, +)) / Double(recent.count)
    }

    // MARK: - Wellbeing (display layer)
    // Positive 0–100 framing of the underlying risk, split into domains for the
    // dashboard. Alerting stays driven by the risk pipeline above — never by these.

    /// Physio wellbeing (0–100, higher = better) — inverse of the physiologic risk.
    /// Shows 100 until calibration completes (UI shows the calibrating state instead).
    var physioWellbeing: Int {
        guard userProfile.calibrationComplete else { return 100 }
        return Int(((1.0 - currentScore) * 100).rounded())
    }

    /// Digital wellbeing (0–100) if digital signals are enabled; nil otherwise.
    /// Wired in Phase 2 — nil for now, so the Digital domain reads "not set up".
    var digitalWellbeing: Int? { nil }

    /// Overall wellbeing — Physio + Digital combined via the selected method.
    var overallWellbeing: Int {
        scoreMethod.combine(physio: physioWellbeing, digital: digitalWellbeing)
    }

    /// Per-signal OK/Watch status for the Physio detail screen, from the latest
    /// snapshot vs. the calibrated thresholds (same checks as `activeTriggers`).
    func physioSignals() -> [SignalStatus] {
        guard let s = latestSnapshot else { return [] }
        let t = userProfile.riskThresholds
        var out: [SignalStatus] = []
        if let hr = s.heartRate {
            out.append(SignalStatus(systemImage: "heart.fill", label: "Heart Rate",
                                    value: "\(Int(hr)) BPM", isGood: hr <= t.highHR))
        }
        if let hrv = s.hrv {
            out.append(SignalStatus(systemImage: "waveform.path.ecg", label: "HRV",
                                    value: "\(Int(hrv)) ms", isGood: hrv >= t.lowHRV))
        }
        if let sleep = s.sleepHours {
            out.append(SignalStatus(systemImage: "moon.fill", label: "Sleep",
                                    value: String(format: "%.1fh", sleep), isGood: sleep >= t.minSleepHours))
        }
        if let steps = s.stepCount {
            out.append(SignalStatus(systemImage: "figure.walk", label: "Steps",
                                    value: "\(steps)", isGood: steps >= 5000))
        }
        return out
    }
}

#if DEBUG
extension RiskScoringEngine {
    /// A calibrated engine seeded with sample data, for SwiftUI previews/canvas.
    /// Same-file access lets us set the `private(set)` snapshot directly.
    static func preview() -> RiskScoringEngine {
        let engine = RiskScoringEngine()
        engine.userProfile.calibrationComplete = true
        engine.currentScore = 0.22
        engine.currentRisk  = .low
        engine.latestSnapshot = BiometricSnapshot(
            heartRate: 72, hrv: 48, sleepHours: 5.4, stepCount: 6421
        )
        engine.recentEvents = [
            RiskEvent(timestamp: Date().addingTimeInterval(-2 * 86_400),
                      severity: .moderate,
                      triggerSignals: ["Low HRV", "Insufficient sleep"],
                      riskScore: 0.42),
            RiskEvent(timestamp: Date().addingTimeInterval(-5 * 86_400),
                      severity: .low,
                      triggerSignals: ["Elevated heart rate"],
                      riskScore: 0.28),
        ]
        return engine
    }
}
#endif
