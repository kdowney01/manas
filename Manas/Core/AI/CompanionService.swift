import Foundation

// MARK: - Doctor Persona

enum DoctorPersona: String, CaseIterable, Identifiable {
    case general  = "general"
    case cbt      = "cbt"
    case anxiety  = "anxiety"
    case trauma   = "trauma"
    case stress   = "stress"
    case mood     = "mood"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general:  return "Dr. Manas"
        case .cbt:      return "Dr. Chen (CBT)"
        case .anxiety:  return "Dr. Patel (Anxiety)"
        case .trauma:   return "Dr. Rivera (Trauma)"
        case .stress:   return "Dr. Kim (Stress)"
        case .mood:     return "Dr. Osei (Mood)"
        }
    }

    var description: String {
        switch self {
        case .general:  return "General mental wellness support"
        case .cbt:      return "Cognitive Behavioral Therapy techniques"
        case .anxiety:  return "Anxiety management & grounding"
        case .trauma:   return "Trauma-informed care & safety"
        case .stress:   return "Stress reduction & resilience"
        case .mood:     return "Mood tracking & emotional balance"
        }
    }

    var systemIconName: String {
        switch self {
        case .general:  return "person.circle.fill"
        case .cbt:      return "brain.filled.head.profile"
        case .anxiety:  return "wind"
        case .trauma:   return "shield.fill"
        case .stress:   return "leaf.fill"
        case .mood:     return "sun.max.fill"
        }
    }

    // On-device keyword-based fallback responses (used when backend is offline).
    // These are safe, evidence-based scripted responses — not raw LLM output.
    func fallbackResponse(for input: String) -> String {
        let lower = input.lowercased()
        switch self {
        case .general:
            if lower.contains("sad") || lower.contains("depressed") || lower.contains("hopeless") {
                return "I hear you. Those feelings are valid. Would it help to share a bit more about what's been happening?"
            }
            return "Thank you for reaching out. I'm here to listen. How are you feeling right now?"

        case .cbt:
            if lower.contains("thought") || lower.contains("think") || lower.contains("believe") {
                return "Let's examine that thought together. What evidence do you have for and against it? CBT helps us notice when thoughts might not reflect reality."
            }
            return "CBT works by connecting our thoughts, feelings, and behaviors. What thought is bothering you most right now?"

        case .anxiety:
            if lower.contains("panic") || lower.contains("anxious") || lower.contains("scared") || lower.contains("overwhelm") {
                return "Let's try a grounding technique. Name 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, 1 you can taste. Take your time."
            }
            return "Anxiety can feel overwhelming. Box breathing often helps: inhale 4 counts, hold 4, exhale 4, hold 4. Try it with me?"

        case .trauma:
            return "You're safe here. We go at whatever pace feels right for you. There's no pressure to share anything you're not ready for."

        case .stress:
            if lower.contains("stress") || lower.contains("work") || lower.contains("busy") || lower.contains("tired") {
                return "Chronic stress depletes us. Let's focus on one small thing you can set aside right now. What's the least urgent item on your mind?"
            }
            return "Your body and mind both respond to stress. A short walk, a glass of water, or even 60 seconds of slow breathing can shift your nervous system."

        case .mood:
            return "Tracking your mood helps reveal patterns. On a scale of 1–10, how would you rate how you feel right now compared to yesterday?"
        }
    }
}

// MARK: - Chat message

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant, system }
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    init(role: Role, content: String) {
        id = UUID()
        self.role = role
        self.content = content
        timestamp = Date()
    }
}

// MARK: - CompanionService

@MainActor
final class CompanionService: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published var selectedPersona: DoctorPersona = .general

    private let backend = BackendService.shared

    func startSession(riskEvent: RiskEvent? = nil, snapshot: BiometricSnapshot? = nil) {
        messages = []
        let greeting = buildGreeting(persona: selectedPersona, riskEvent: riskEvent)
        messages.append(ChatMessage(role: .assistant, content: greeting))
    }

    func send(_ text: String, snapshot: BiometricSnapshot?) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: text))
        isLoading = true
        defer { isLoading = false }

        let context = ChatContext(
            riskLevel: snapshot.map { RiskScoringEngine.severityLabel(for: $0) } ?? "unknown",
            stressIndex: snapshot?.stressIndex.rawValue ?? "unknown"
        )

        do {
            guard backend.isAuthenticated else { throw BackendError.notAuthenticated }
            let reply = try await backend.chat(
                message: text,
                persona: selectedPersona.rawValue,
                context: context
            )
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            // On-device fallback — never fails the user silently
            let fallback = selectedPersona.fallbackResponse(for: text)
            messages.append(ChatMessage(role: .assistant, content: fallback))
        }
    }

    func clearSession() {
        messages = []
    }

    // MARK: - Private

    private func buildGreeting(persona: DoctorPersona, riskEvent: RiskEvent?) -> String {
        let name = persona.displayName
        if let event = riskEvent, event.severity >= .high {
            return "Hi, I'm \(name). Manas noticed some elevated signals — I'm here if you'd like to talk. How are you feeling right now?"
        }
        return "Hi, I'm \(name). \(persona.description). What's on your mind today?"
    }
}

// MARK: - Helper used by CompanionService

private extension RiskScoringEngine {
    static func severityLabel(for snapshot: BiometricSnapshot) -> String {
        snapshot.stressIndex.rawValue
    }
}
