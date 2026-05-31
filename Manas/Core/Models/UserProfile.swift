import Foundation

struct UserProfile: Codable {
    var baselineHRV: Double?            // personalized RMSSD baseline (ms)
    var baselineRestingHR: Double?      // BPM
    var baselineSleepHours: Double?
    var calibrationComplete: Bool
    var calibrationSampleCount: Int
    var riskThresholds: RiskThresholds

    static let calibrationTargetSamples = 7 * 24  // 7 days of hourly samples

    init() {
        self.baselineHRV = nil
        self.baselineRestingHR = nil
        self.baselineSleepHours = nil
        self.calibrationComplete = false
        self.calibrationSampleCount = 0
        self.riskThresholds = RiskThresholds()
    }

    // After calibration, derive thresholds from personal baseline
    mutating func finalizeCalibration(snapshots: [BiometricSnapshot]) {
        let hrvValues = snapshots.compactMap(\.hrv)
        let hrValues = snapshots.compactMap(\.heartRate)
        let sleepValues = snapshots.compactMap(\.sleepHours)

        if !hrvValues.isEmpty {
            baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        }
        if !hrValues.isEmpty {
            baselineRestingHR = hrValues.reduce(0, +) / Double(hrValues.count)
        }
        if !sleepValues.isEmpty {
            baselineSleepHours = sleepValues.reduce(0, +) / Double(sleepValues.count)
        }

        riskThresholds = RiskThresholds.from(
            baselineHRV: baselineHRV,
            baselineHR: baselineRestingHR
        )
        calibrationComplete = true
    }
}

struct RiskThresholds: Codable {
    var lowHRV: Double          // below this = stress signal
    var criticalHRV: Double
    var highHR: Double          // above this = elevated HR signal
    var minSleepHours: Double

    init() {
        // Population defaults until personal baseline is established
        self.lowHRV = 35.0
        self.criticalHRV = 20.0
        self.highHR = 85.0
        self.minSleepHours = 6.0
    }

    static func from(baselineHRV: Double?, baselineHR: Double?) -> RiskThresholds {
        var t = RiskThresholds()
        if let hrv = baselineHRV {
            t.lowHRV = hrv * 0.75      // 25% below personal baseline
            t.criticalHRV = hrv * 0.50 // 50% below personal baseline
        }
        if let hr = baselineHR {
            t.highHR = hr * 1.15       // 15% above personal resting HR
        }
        return t
    }
}
