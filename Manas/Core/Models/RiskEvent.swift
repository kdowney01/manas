import Foundation

struct RiskEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let severity: RiskSeverity
    let triggerSignals: [String]
    let riskScore: Double
    var acknowledged: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        severity: RiskSeverity,
        triggerSignals: [String],
        riskScore: Double,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.triggerSignals = triggerSignals
        self.riskScore = riskScore
        self.acknowledged = acknowledged
    }
}

enum RiskSeverity: String, Codable, Comparable {
    case low
    case moderate
    case high
    case crisis

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .crisis: return "Crisis"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .crisis: return "red"
        }
    }

    static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        let order: [RiskSeverity] = [.low, .moderate, .high, .crisis]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
