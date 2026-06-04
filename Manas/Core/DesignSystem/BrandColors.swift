import SwiftUI

// MARK: - MANAS Brand Palette
// Source: MANAS Branding Guidelines (Impact Project Problem Statement deck)

extension Color {
    /// Indigo Blue #5c6cb3 — trust, calm focus, reliability. Primary action color.
    static let manasPrimary    = Color(red: 92/255,  green: 108/255, blue: 179/255)
    /// Lavender Purple #ad6cad — compassion, creativity, emotional balance.
    static let manasSecondary  = Color(red: 173/255, green: 108/255, blue: 173/255)
    /// Soft Mint #a8e6cf — freshness, growth, positivity.
    static let manasMint       = Color(red: 168/255, green: 230/255, blue: 207/255)
    /// Warm Peach #ffb397 — empathy, warmth, approachability.
    static let manasPeach      = Color(red: 255/255, green: 179/255, blue: 151/255)
    /// Cool Gray #f4f4f7 — clean neutral base.
    static let manasBackground = Color(red: 244/255, green: 244/255, blue: 247/255)
}

// MARK: - Risk Severity Colors
extension RiskSeverity {
    /// Semantic foreground color for each risk level.
    var swiftUIColor: Color {
        switch self {
        case .low:      return Color(red: 52/255,  green: 199/255, blue: 89/255)  // iOS system green
        case .moderate: return Color(red: 255/255, green: 204/255, blue: 0/255)   // iOS system yellow
        case .high:     return Color(red: 255/255, green: 149/255, blue: 0/255)   // iOS system orange
        case .crisis:   return Color(red: 255/255, green: 59/255,  blue: 48/255)  // iOS system red
        }
    }

    /// Tinted fill for badges and backgrounds.
    var swiftUIBackgroundColor: Color { swiftUIColor.opacity(0.13) }

    /// Subtle border for outlined treatments.
    var swiftUIBorderColor: Color { swiftUIColor.opacity(0.28) }
}
