import Foundation

// MARK: - Wellbeing scoring (display layer)
//
// "Wellbeing" is the user-facing, positive framing of risk: 0–100, higher = better.
// Internally the engine still computes *risk* (0–1, higher = worse) for safety and
// alerting; these helpers translate that into the three-domain wellbeing model
// (Physio / Digital / Overall) shown on the dashboard. Mirrors the HTML prototype.

/// How the Overall wellbeing score combines the Physio and Digital domain scores.
/// User-selectable in Settings.
enum ScoreMethod: String, CaseIterable, Identifiable, Codable {
    case average
    case physioWeighted
    case lowestPullsDown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .average:         return "Equal average"
        case .physioWeighted:  return "Physio-weighted"
        case .lowestPullsDown: return "Lowest pulls down"
        }
    }

    var blurb: String {
        switch self {
        case .average:         return "Your Physio and Digital scores, averaged equally."
        case .physioWeighted:  return "Weighted 60% Physio, 40% Digital."
        case .lowestPullsDown: return "Weighted toward your weaker domain, so one low area isn't masked."
        }
    }

    /// Combine two domain scores (0–100). When `digital` is nil (not set up),
    /// Overall is simply the Physio score.
    func combine(physio: Int, digital: Int?) -> Int {
        guard let digital else { return physio }
        let p = Double(physio), d = Double(digital)
        switch self {
        case .average:
            return Int(((p + d) / 2.0).rounded())
        case .physioWeighted:
            return Int((p * 0.6 + d * 0.4).rounded())
        case .lowestPullsDown:
            let lo = min(p, d), hi = max(p, d)
            return Int((lo * 0.65 + hi * 0.35).rounded())
        }
    }
}

/// One signal's status within a domain, for the detail-screen tiles.
/// Color is decided in the view; Core stays UI-free (SF Symbol name is just a string).
struct SignalStatus: Identifiable {
    let id = UUID()
    let systemImage: String
    let label: String
    let value: String
    let isGood: Bool
}

/// Display helpers for the wellbeing model — score → band, tone-aware commentary, tips.
enum Wellbeing {

    /// Map a 0–100 wellbeing score onto a severity band (for color + label).
    static func band(for score: Int) -> RiskSeverity {
        switch score {
        case 75...: return .low        // good
        case 55...: return .moderate
        case 35...: return .high
        default:    return .crisis
        }
    }

    // Short, tone-aware commentary — playful when high, gentle and encouraging when low.

    static func overallCommentary(_ score: Int) -> String {
        switch score {
        case 85...: return "You're absolutely glowing today — whatever you're doing, keep it up."
        case 75...: return "Feeling good. Mind and body are in a nice rhythm right now."
        case 55...: return "A bit of a mixed bag today — go easy on yourself, you're doing fine."
        case 35...: return "Things feel heavier than usual. Small steps count, and you've got this."
        default:    return "You're carrying a lot right now. Be gentle with yourself — you're not alone in this."
        }
    }

    static func physioCommentary(_ score: Int) -> String {
        switch score {
        case 85...: return "Your body's running like a dream — well rested and recharged."
        case 75...: return "Nice and steady — heart, sleep, and movement are all on your side."
        case 55...: return "Your body's asking for a little extra care today. Hydrate and breathe."
        case 35...: return "Running low on reserves. Rest counts too — be kind to your body."
        default:    return "Your body's under real strain right now. Please slow down and lean on support."
        }
    }

    static func digitalCommentary(_ score: Int) -> String {
        switch score {
        case 85...: return "Your digital habits are in a great place — balanced and breezy."
        case 75...: return "Nice balance online today — screen and social habits look healthy."
        case 55...: return "Things are creeping up a little online. A short screen break could help."
        case 35...: return "Screens and feeds are taking a toll. A little unplugging goes a long way."
        default:    return "Your digital world feels heavy right now. You deserve a real break — and real support."
        }
    }

    /// A short, supportive tip for a flagged Physio signal.
    static func physioTip(forLabel label: String) -> String {
        switch label {
        case "Heart Rate": return "Resting HR is outside your typical band — hydration, caffeine, or stress can contribute."
        case "HRV":        return "Lower HRV can signal accumulated stress or under-recovery. Prioritize rest today."
        case "Sleep":      return "You slept less than your baseline. Aim for a consistent wind-down tonight."
        case "Steps":      return "Activity dipped below your usual level. A short walk can help reset."
        default:           return "This signal is outside your usual range."
        }
    }
}
