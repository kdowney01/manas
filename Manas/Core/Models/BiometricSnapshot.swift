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
    var emotionVector: EmotionVector?  // nil if camera unavailable/not consented

    var stressIndex: StressIndex {
        StressIndex.compute(heartRate: heartRate, hrv: hrv, emotion: emotionVector)
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        hrv: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        stepCount: Int? = nil,
        activeEnergyBurned: Double? = nil,
        emotionVector: EmotionVector? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.stepCount = stepCount
        self.activeEnergyBurned = activeEnergyBurned
        self.emotionVector = emotionVector
    }
}

enum StressIndex: String, Codable {
    case calm
    case elevated
    case high

    // Multimodal stress computation:
    // Physiological: elevated HR + suppressed HRV (per MAANAS rPPG processor)
    // Facial: high emotion stress signal (fearful + angry + disgusted)
    // Either source alone can elevate the index; both together = definitive.
    static func compute(heartRate: Double?, hrv: Double?, emotion: EmotionVector? = nil) -> StressIndex {
        let physioStress: Int = {
            guard let hr = heartRate, let hrv = hrv else { return 0 }
            if hr > 90 && hrv < 20 { return 2 }
            if hr > 80 && hrv < 35 { return 1 }
            return 0
        }()

        let emotionStress: Int = {
            guard let e = emotion else { return 0 }
            if e.stressSignal > 0.6 { return 2 }
            if e.stressSignal > 0.35 { return 1 }
            return 0
        }()

        let combined = max(physioStress, emotionStress)
        switch combined {
        case 2...: return .high
        case 1:    return .elevated
        default:   return .calm
        }
    }
}
