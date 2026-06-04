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

        // Add your server's SHA-256 public key hashes here before shipping.
        // Generate with: openssl s_client -connect api.maanas.health:443 | \
        //   openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | \
        //   openssl dgst -sha256 -binary | base64
        let pinHash = Self.resolve("MAANAS_PIN_HASH", plist: plist, default: "")
        tlsPinnedHashes = pinHash.isEmpty ? [] : [pinHash]

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
