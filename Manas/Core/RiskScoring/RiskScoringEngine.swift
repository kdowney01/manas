import Foundation
import Combine

@MainActor
final class RiskScoringEngine: ObservableObject {
    @Published var currentRisk: RiskSeverity = .low
    @Published var currentScore: Double = 0.0
    @Published var recentEvents: [RiskEvent] = []
    @Published var userProfile = UserProfile()

    private var snapshotHistory: [BiometricSnapshot] = []

    func process(_ snapshot: BiometricSnapshot) {
        snapshotHistory.append(snapshot)
        if snapshotHistory.count > 7 * 24 { snapshotHistory.removeFirst() }

        if !userProfile.calibrationComplete {
            userProfile.calibrationSampleCount += 1
            if userProfile.calibrationSampleCount >= 7 {
                userProfile.finalizeCalibration(snapshots: snapshotHistory)
            }
            return
        }

        let score = computeScore(snapshot)
        currentScore = score
        currentRisk = severity(for: score)

        if currentRisk >= .high {
            let event = RiskEvent(
                severity: currentRisk,
                triggerSignals: activeTriggers(snapshot),
                riskScore: score
            )
            recentEvents.insert(event, at: 0)
            if recentEvents.count > 50 { recentEvents.removeLast() }
        }
    }

    // Weighted scoring across biometric signals
    // Based on MAANAS rPPG physiological homeostasis assessment logic
    private func computeScore(_ s: BiometricSnapshot) -> Double {
        var score = 0.0
        let thresholds = userProfile.riskThresholds

        // HRV signal (weight: 0.40) — suppressed HRV is strongest stress indicator
        if let hrv = s.hrv {
            if hrv < thresholds.criticalHRV {
                score += 0.40
            } else if hrv < thresholds.lowHRV {
                score += 0.20
            }
        }

        // Heart rate signal (weight: 0.30)
        if let hr = s.heartRate {
            if hr > thresholds.highHR * 1.15 {
                score += 0.30
            } else if hr > thresholds.highHR {
                score += 0.15
            }
        }

        // Sleep signal (weight: 0.20)
        if let sleep = s.sleepHours {
            if sleep < thresholds.minSleepHours * 0.75 {
                score += 0.20
            } else if sleep < thresholds.minSleepHours {
                score += 0.10
            }
        }

        // Activity anomaly (weight: 0.10) — sudden drop in steps vs recent average
        let recentStepAvg = recentStepAverage()
        if let steps = s.stepCount, let avg = recentStepAvg, avg > 0 {
            let ratio = Double(steps) / avg
            if ratio < 0.30 { score += 0.10 }
            else if ratio < 0.50 { score += 0.05 }
        }

        return min(score, 1.0)
    }

    private func severity(for score: Double) -> RiskSeverity {
        switch score {
        case 0.75...: return .crisis
        case 0.50...: return .high
        case 0.25...: return .moderate
        default: return .low
        }
    }

    private func activeTriggers(_ s: BiometricSnapshot) -> [String] {
        var triggers: [String] = []
        let t = userProfile.riskThresholds
        if let hrv = s.hrv, hrv < t.lowHRV { triggers.append("Low HRV (\(Int(hrv))ms)") }
        if let hr = s.heartRate, hr > t.highHR { triggers.append("Elevated HR (\(Int(hr)) BPM)") }
        if let sleep = s.sleepHours, sleep < t.minSleepHours { triggers.append("Low sleep (\(String(format: "%.1f", sleep))h)") }
        return triggers
    }

    private func recentStepAverage() -> Double? {
        let recentWithSteps = snapshotHistory.suffix(7).compactMap(\.stepCount)
        guard !recentWithSteps.isEmpty else { return nil }
        return Double(recentWithSteps.reduce(0, +)) / Double(recentWithSteps.count)
    }
}
