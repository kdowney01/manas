import Foundation

struct BiometricSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double?          // BPM
    let hrv: Double?                // RMSSD in ms
    let restingHeartRate: Double?   // BPM
    let sleepHours: Double?
    let stepCount: Int?
    let activeEnergyBurned: Double? // kcal

    var stressIndex: StressIndex {
        StressIndex.compute(heartRate: heartRate, hrv: hrv)
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        hrv: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        stepCount: Int? = nil,
        activeEnergyBurned: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.stepCount = stepCount
        self.activeEnergyBurned = activeEnergyBurned
    }
}

enum StressIndex: String, Codable {
    case calm
    case elevated
    case high

    // Elevated HR + suppressed HRV = stress (per MAANAS rPPG processor logic)
    static func compute(heartRate: Double?, hrv: Double?) -> StressIndex {
        guard let hr = heartRate, let hrv = hrv else { return .calm }
        if hr > 90 && hrv < 20 { return .high }
        if hr > 80 && hrv < 35 { return .elevated }
        return .calm
    }
}
