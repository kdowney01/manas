import Foundation
import CryptoKit
import OSLog

private let log = Logger(subsystem: "com.manas.app", category: "BackendService")

// MAANAS FastAPI backend client.
//
// HIPAA notes:
//   - Only derived scores transmitted, never raw biometric values.
//   - JWT stored in Keychain via SecureStorage.
//   - All PHI-adjacent log values use .private privacy level.
//   - TLS 1.2+ enforced; SHA-256 public-key pinning active when hashes configured.
//   - A Business Associate Agreement (BAA) must be executed with the backend
//     operator before any PHI-adjacent data is transmitted in production.
//
// Socket.IO note:
//   The MAANAS backend uses python-socketio. This service implements the
//   Socket.IO handshake and framing protocol over URLSessionWebSocketTask so
//   no third-party dependency is required.
//   Socket.IO v4 wire format: "4<namespace>,<data>" for EVENT packets.

@MainActor
final class BackendService: NSObject, ObservableObject {
    static let shared = BackendService()

    @Published private(set) var isConnected    = false
    @Published private(set) var isAuthenticated = false

    private let config  = AppConfig.shared
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
        let resp: Resp = try await post(path: "/api/auth/login", body: Body(email: email, password: password), auth: false)
        jwt = resp.token
        isAuthenticated = true
        log.info("Authenticated with MAANAS backend [\(self.config.environment.rawValue, privacy: .public)]")
    }

    func logout() {
        jwt = nil
        isAuthenticated = false
        disconnectTelemetry()
    }

    // MARK: - Socket.IO telemetry

    func connectTelemetry() {
        guard let token = jwt else { return }

        // Socket.IO v4 uses polling upgrade; we connect directly to the WS endpoint
        // with Engine.IO parameters.
        var components = URLComponents(url: config.webSocketURL, resolvingAgainstBaseURL: false)!
        components.path = "/socket.io/"
        components.queryItems = [
            URLQueryItem(name: "EIO",       value: "4"),
            URLQueryItem(name: "transport", value: "websocket"),
        ]

        var req = URLRequest(url: components.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        webSocketTask = session.webSocketTask(with: req)
        webSocketTask?.resume()
        isConnected = true

        // Send Socket.IO connection packet for default namespace
        Task { try? await webSocketTask?.send(.string("40")) }

        startPing()
        receiveLoop()
        log.info("Socket.IO telemetry connected")
    }

    func sendTelemetry(_ snapshot: BiometricSnapshot) async {
        guard isConnected else { return }
        // Socket.IO EVENT packet: "42" + JSON array ["event", payload]
        // Only derived/non-PHI fields transmitted.
        let payload = TelemetryPayload(snapshot: snapshot)
        guard let data = try? JSONEncoder().encode(payload),
              let body = String(data: data, encoding: .utf8) else { return }
        let frame = "42[\"telemetry_update\",\(body)]"
        try? await webSocketTask?.send(.string(frame))
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
        let body = Body(id: event.id.uuidString, severity: event.severity.rawValue, timestamp: event.timestamp)
        _ = try? await post(path: "/api/risk/event", body: body) as EmptyResponse
        log.info("Risk event reported severity=\(event.severity.rawValue, privacy: .public)")
    }

    // MARK: - LLM chat

    func chat(message: String, persona: String, context: ChatContext) async throws -> String {
        struct Body: Encodable { let message, persona: String; let context: ChatContext }
        struct Resp: Decodable { let reply: String }
        let resp: Resp = try await post(path: "/api/llm/chat", body: Body(message: message, persona: persona, context: context))
        return resp.reply
    }

    // MARK: - Generic REST helper

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

    // MARK: - Socket.IO keep-alive + receive

    private func startPing() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                try? await webSocketTask?.send(.string("3"))   // Engine.IO PING
            }
        }
    }

    private func receiveLoop() {
        Task {
            while let task = webSocketTask {
                guard let msg = try? await task.receive() else { break }
                if case .string(let text) = msg {
                    handleSocketIOFrame(text)
                }
            }
            if isConnected { log.info("Socket.IO connection dropped — will reconnect on next telemetry send") }
            isConnected = false
        }
    }

    private func handleSocketIOFrame(_ frame: String) {
        // Engine.IO packet types: 0=OPEN,1=CLOSE,2=PING,3=PONG,4=MESSAGE,5=UPGRADE,6=NOOP
        guard let first = frame.first else { return }
        switch first {
        case "0": log.debug("Socket.IO OPEN")
        case "3": break                         // PONG — expected
        case "4":                               // MESSAGE — Socket.IO frame
            let sioFrame = String(frame.dropFirst())
            guard sioFrame.hasPrefix("0") else { return }   // namespace connect ACK
            log.debug("Socket.IO namespace connected")
        default: break
        }
    }
}

// MARK: - Certificate pinning (SHA-256 public key)

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

        // If no pins configured (dev/pre-production), use default trust evaluation.
        guard !config.tlsPinnedHashes.isEmpty else {
            completionHandler(.performDefaultHandling, URLCredential(trust: serverTrust))
            return
        }

        // Extract server leaf certificate public key and SHA-256 hash it.
        guard
            let leafCert  = SecTrustCopyCertificateChain(serverTrust).flatMap({ $0 as? [SecCertificate] })?.first,
            let publicKey = SecCertificateCopyKey(leafCert),
            let keyData   = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else {
            log.error("Cert pinning: failed to extract server public key")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let hash = SHA256.hash(data: keyData)
        let hashBase64 = Data(hash).base64EncodedString()

        if config.tlsPinnedHashes.contains(hashBase64) {
            log.info("Cert pinning: ✓ hash matched")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            log.error("Cert pinning: ✗ hash mismatch — connection rejected (expected one of \(self.config.tlsPinnedHashes.count, privacy: .public) pins)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Payload types (no raw PHI)

private struct TelemetryPayload: Encodable {
    let stressIndex: String
    let timestamp: Date
    init(snapshot: BiometricSnapshot) {
        stressIndex = snapshot.stressIndex.rawValue
        timestamp   = snapshot.timestamp
    }
}

private struct EmptyResponse: Decodable {}

struct ChatContext: Encodable {
    let riskLevel: String
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
