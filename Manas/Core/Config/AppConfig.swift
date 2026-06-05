import Foundation

// MARK: - AppConfig
// Single source of truth for runtime configuration.
// Resolution order (first match wins):
//   1. ManasDev.plist in the app bundle (gitignored, for local dev overrides)
//   2. Xcode scheme environment variable (MAANAS_API_URL, MAANAS_ENV)
//   3. Compiled-in defaults (safe for production)
//
// To set a local override: copy ManasDev.plist.template → ManasDev.plist
// and add it to the Xcode target (do NOT commit it).

enum Environment: String {
    case development = "development"
    case staging     = "staging"
    case production  = "production"
}

struct AppConfig {
    static let shared = AppConfig()

    let environment: Environment
    let apiBaseURL: URL
    let webSocketURL: URL
    let tlsPinnedHashes: [String]   // SHA-256 of server public key(s), base64-encoded
    let baaConfirmed: Bool           // BAA with backend operator executed — gates PHI-adjacent calls
    let logLevel: LogLevel

    private init() {
        let plist   = Self.loadDevPlist()
        let env     = Self.resolve("MAANAS_ENV", plist: plist, default: "production")
        environment = Environment(rawValue: env) ?? .production

        let apiString = Self.resolve(
            "MAANAS_API_URL", plist: plist,
            default: "http://localhost:8000"
        )
        apiBaseURL    = URL(string: apiString)!

        let wsString  = Self.resolve(
            "MAANAS_WS_URL", plist: plist,
            default: apiString.replacingOccurrences(of: "https://", with: "wss://")
                               .replacingOccurrences(of: "http://", with: "ws://")
        )
        webSocketURL  = URL(string: wsString)!

        // TLS cert pinning — intermediate CA hash.
        // Generate with: scripts/generate_pin_hash.sh api.maanas.health
        let pinHash = Self.resolve("MAANAS_PIN_HASH", plist: plist, default: "")
        tlsPinnedHashes = pinHash.isEmpty ? [] : [pinHash]

        // BAA gate — must be true before any PHI-adjacent data is transmitted.
        // Set MAANAS_BAA_CONFIRMED = true in ManasDev.plist once BAA is executed.
        // See docs/compliance/BAA_REQUIREMENTS.md for what must be in place first.
        let baaFlag = Self.resolve("MAANAS_BAA_CONFIRMED", plist: plist, default: "false")
        baaConfirmed = baaFlag.lowercased() == "true"

        logLevel = environment == .production ? .warning : .debug
    }

    // MARK: - Helpers

    private static func loadDevPlist() -> [String: String]? {
        guard let url = Bundle.main.url(forResource: "ManasDev", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else { return nil }
        return dict
    }

    private static func resolve(_ key: String, plist: [String: String]?, default fallback: String) -> String {
        plist?[key]
            ?? ProcessInfo.processInfo.environment[key]
            ?? fallback
    }
}

enum LogLevel: Int, Comparable {
    case debug = 0, info, warning, error
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Dev plist template
// Save as Manas/Resources/ManasDev.plist (gitignored) and add to Xcode target:
//
// <?xml version="1.0" encoding="UTF-8"?>
// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
// <plist version="1.0"><dict>
//   <key>MAANAS_ENV</key>     <string>development</string>
//   <key>MAANAS_API_URL</key> <string>http://localhost:8000</string>
//   <key>MAANAS_WS_URL</key>  <string>ws://localhost:8000</string>
//   <key>MAANAS_PIN_HASH</key><string></string>
// </dict></plist>
