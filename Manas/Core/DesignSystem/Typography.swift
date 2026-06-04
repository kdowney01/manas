import SwiftUI

// MARK: - MANAS Typography System
// Brand font: Montserrat (both headers and body per branding guidelines)
//
// Setup required:
//   1. Download Montserrat from https://fonts.google.com/specimen/Montserrat
//   2. Add these weights to Manas/Resources/Fonts/:
//      Montserrat-Regular.ttf, Montserrat-Medium.ttf, Montserrat-SemiBold.ttf,
//      Montserrat-Bold.ttf, Montserrat-ExtraBold.ttf
//   3. Register all five in Info.plist under UIAppFonts (already added)
//   4. Add all font files to the Xcode target (Build Phases → Copy Bundle Resources)
//
// Until fonts are bundled, Font.custom falls back to SF Pro automatically.

extension Font {
    // App wordmark — "manas" in nav bar + welcome screen
    static let manasWordmark    = Font.custom("Montserrat-ExtraBold", size: 34, relativeTo: .largeTitle)

    // Headings
    static let manasLargeTitle  = Font.custom("Montserrat-Bold",     size: 34, relativeTo: .largeTitle)
    static let manasTitle       = Font.custom("Montserrat-Bold",     size: 28, relativeTo: .title)
    static let manasTitle2      = Font.custom("Montserrat-SemiBold", size: 22, relativeTo: .title2)
    static let manasTitle3      = Font.custom("Montserrat-SemiBold", size: 20, relativeTo: .title3)

    // Body
    static let manasHeadline    = Font.custom("Montserrat-SemiBold", size: 17, relativeTo: .headline)
    static let manasBody        = Font.custom("Montserrat-Regular",  size: 17, relativeTo: .body)
    static let manasCallout     = Font.custom("Montserrat-Medium",   size: 16, relativeTo: .callout)
    static let manasSubheadline = Font.custom("Montserrat-Regular",  size: 15, relativeTo: .subheadline)

    // Support
    static let manasFootnote    = Font.custom("Montserrat-Regular",  size: 13, relativeTo: .footnote)
    static let manasCaption     = Font.custom("Montserrat-Regular",  size: 12, relativeTo: .caption)
    static let manasCaption2    = Font.custom("Montserrat-Regular",  size: 11, relativeTo: .caption2)
}
