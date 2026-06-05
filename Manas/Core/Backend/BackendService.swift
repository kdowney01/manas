import Foundation
import CryptoKit
import OSLog

private let log = Logger(subsystem: "com.manas.app", category: "BackendService")

// MAANAS FastAPI backend client.
//
// Transport: native WebSocket (URLSessionWebSocketTask) — see ADR-003.
// The backend exposes a /ws/telemetry endpoint alongside the existing Socket.IO
// server, so React/MaanasWatch clients are unaffected.
//
// HIPAA notes:
//   - Only derived scores transmitted, never raw biometric values.
//   - JWT stored in Keychain via SecureStorage.
//   - All PHI-adjacent log values use .private privacy level.
//   - TLS 1.2+ enforced; SHA-256 public-key pinning active when hashes configured.
//   - A Business Associate Agreement (BAA) must be executed with the backend
//     operator before any PHI-adjacent data is transmitted in production.

@MainActor
final class BackendService: NSObject, ObservableObject {
    static let shared = BackendService()

    @Published private(set) var isConnected     = false
    @Published private(set) var isAuthenticated = false

    private let config = AppConfig.shared
    private var jwt: String? {
        get { try? SecureStorage.shared.loadString(key: SecureStorage.Keys.jwtToken.rawValue) }
        set {
            if let t = newValue {
                try? SecureStorage.shared.saveString(t, key: SecureStorage.Keys.jwtToken.rawValue)
            } else {
                SecureStorage.shared.delete(key: SecureStorage.Keys.jwtToken.rawValue)
            }
        }
    }

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 60
        cfg.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?

    // MARK: - Authentication

    func login(email: String, password: String) async throws {
        struct Body: Encodable { let email, password: String }
        struct Resp: Decodable { let token: String }
        let resp: Resp = try await post(path: "/api/auth/login",
                                        body: Body(email: email, password: password),
                                        auth: false)
        jwt = resp.token
        isAuthenticated = true
        log.info("Authenticated with MAANAS backend [\(self.config.environment.rawValue, privacy: .public)]")
    }

    func logout() {
        jwt = nil
        isAuthenticated = false
        disconnectTelemetry()
    }

    // MARK: - Native WebSocket telemetry (ADR-003)
    // Connects to /ws/telemetry?token=<jwt>
    // Exchanges plain JSON objects — no Socket.IO framing.

    func connectTelemetry() {
        guard let token = jwt else { return }

        var components = URLComponents(url: config.webSocketURL.appendingPathComponent("/ws/telemetry"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let url = components.url else { return }
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        log.info("WebSocket telemetry connected to \(url.host ?? "", privacy: .public)")

        startPing()
        receiveLoop()
    }

    func sendTelemetry(_ snapshot: BiometricSnapshot) async {
        guard isConnected else { return }
        let payload = TelemetryPayload(snapshot: snapshot)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        try? await webSocketTask?.send(.string(json))
    }

    func disconnectTelemetry() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Risk event reporting

    func reportRiskEvent(_ event: RiskEvent) async {
        guard isAuthenticated else { return }
        struct Body: Encodable { let id, severity: String; let timestamp: Date }
        let body = Body(id: event.id.uuidString,
                        severity: event.severity.rawValue,
                        timestamp: event.timestamp)
        _ = try? await post(path: "/api/risk/event", body: body) as EmptyResponse
        log.info("Risk event reported severity=\(event.severity.rawValue, privacy: .public)")
    }

    // MARK: - LLM chat

    func chat(message: String, persona: String, context: ChatContext) async throws -> String {
        struct Body: Encodable { let message, persona: String; let context: ChatContext }
        struct Resp: Decodable { let reply: String }
        let resp: Resp = try await post(path: "/api/llm/chat",
                                        body: Body(message: message, persona: persona, context: context))
        return resp.reply
    }

    // MARK: - Generic REST

    private func post<B: Encodable, R: Decodable>(path: String, body: B, auth: Bool = true) async throws -> R {
        var req = URLRequest(url: config.apiBaseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token = jwt {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackendError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(R.self, from: data)
    }

    // MARK: - WebSocket keep-alive & receive

    private func startPing() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                webSocketTask?.sendPing { _ in }   // native WebSocket ping frame
            }
        }
    }

    private func receiveLoop() {
        Task {
            while let task = webSocketTask {
                guard let message = try? await task.receive() else { break }
                if case .string(let text) = message {
                    handleMessage(text)
                }
            }
            if isConnected {
                isConnected = false
                log.info("WebSocket disconnected")
            }
        }
    }

    private func handleMessage(_ text: String) {
        // Server acknowledgements arrive as {"status":"ok","event":"..."}
        // Future: handle server-push events here (e.g. care recommendations)
        log.debug("WebSocket message received")
    }
}

// MARK: - Certificate pinning (SHA-256 public key, intermediate CA)
//
// Pins the intermediate CA rather than the leaf cert (ADR-003).
// Walks the full certificate chain — if ANY cert's public key hash matches
// a configured pin, the connection is trusted. This means the pin survives
// leaf cert rotation as long as the same CA is used.
//
// To generate the hash for your server:
//   scripts/generate_pin_hash.sh api.maanas.health
// Then add the intermediate hash to ManasDev.plist as MAANAS_PIN_HASH.

extension BackendService: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // No pins configured (dev/pre-production) — use default trust evaluation.
        guard !config.tlsPinnedHashes.isEmpty else {
            log.info("Cert pinning: no pins configured — using default trust (dev mode)")
            completionHandler(.performDefaultHandling, URLCredential(trust: serverTrust))
            return
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            log.error("Cert pinning: failed to copy certificate chain")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Walk the chain — check leaf, intermediate(s), and root against pinned hashes.
        let matched = chain.contains { cert in
            guard
                let publicKey = SecCertificateCopyKey(cert),
                let keyData   = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
            else { return false }
            let hash = Data(SHA256.hash(data: keyData)).base64EncodedString()
            return config.tlsPinnedHashes.contains(hash)
        }

        if matched {
            log.info("Cert pinning: ✓ chain contains a pinned hash")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            log.error("Cert pinning: ✗ no cert in chain matched — connection rejected")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Payload types (no raw PHI)

private struct TelemetryPayload: Encodable {
    let event      = "telemetry_update"
    let stressIndex: String
    let timestamp:   Date
    init(snapshot: BiometricSnapshot) {
        stressIndex = snapshot.stressIndex.rawValue
        timestamp   = snapshot.timestamp
    }
}

private struct EmptyResponse: Decodable {}

struct ChatContext: Encodable {
    let riskLevel:   String
    let stressIndex: String
}

// MARK: - Errors

enum BackendError: LocalizedError {
    case authFailed, notAuthenticated, chatFailed, httpError(Int)
    var errorDescription: String? {
        switch self {
        case .authFailed:          return "Authentication failed"
        case .notAuthenticated:    return "Not authenticated"
        case .chatFailed:          return "Companion request failed"
        case .httpError(let code): return "HTTP \(code)"
        }
    }
}
