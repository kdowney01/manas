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

    private var snapshotHistory: [BiometricSnapshot] = []
    private let alertManager = AlertManager.shared
    private let backend = BackendService.shared

    func process(_ snapshot: BiometricSnapshot) {
        snapshotHistory.append(snapshot)
        if snapshotHistory.count > 7 * 24 { snapshotHistory.removeFirst() }

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
}
