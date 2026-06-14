import Foundation
import UserNotifications
import OSLog

private let log = Logger(subsystem: "com.manas.app", category: "AlertManager")

// HIPAA note: notification content must never include raw biometric readings.
// Only general-language nudges are sent; specifics live inside the app.

@MainActor
final class AlertManager: NSObject, ObservableObject {
    static let shared = AlertManager()

    @Published var activeCrisisEvent: RiskEvent?   // set → CrisisView presents
    @Published var notificationsAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private var lastEscalatedSeverity: RiskSeverity = .low

    private override init() {
        super.init()
        center.delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationsAuthorized = granted
            log.info("Notification authorization: \(granted ? "granted" : "denied", privacy: .public)")
        } catch {
            log.error("Notification authorization error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Risk event handling (called by RiskScoringEngine)

    func handle(event: RiskEvent) {
        guard event.severity >= .high else { return }

        switch event.severity {
        case .high where lastEscalatedSeverity < .high:
            scheduleHighRiskNudge(event)
            lastEscalatedSeverity = .high
        case .crisis:
            activeCrisisEvent = event
            scheduleCrisisNotification(event)
            lastEscalatedSeverity = .crisis
        default:
            break
        }
    }

    func clearCrisis() {
        activeCrisisEvent = nil
        lastEscalatedSeverity = .low
    }

    // MARK: - Notification payloads
    // No PHI in title/body — values stay inside the app.

    private func scheduleHighRiskNudge(_ event: RiskEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Check in with yourself"
        content.body = "Manas has noticed some changes in your wellbeing signals. Open the app to see more."
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = "HIGH_RISK"
        content.userInfo = ["eventId": event.id.uuidString]

        schedule(content: content, id: "manas.high.\(event.id.uuidString)", delay: 1)
        log.info("Scheduled high-risk nudge notification")
    }

    private func scheduleCrisisNotification(_ event: RiskEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Immediate support is available"
        content.body = "Multiple stress signals detected. Tap to access crisis resources and alert your contacts."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alert_crisis.caf"))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "CRISIS"
        content.userInfo = ["eventId": event.id.uuidString]

        schedule(content: content, id: "manas.crisis.\(event.id.uuidString)", delay: 1)
        log.info("Scheduled crisis notification")
    }

    private func schedule(content: UNMutableNotificationContent, id: String, delay: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error { log.error("Failed to schedule notification: \(error.localizedDescription, privacy: .public)") }
        }
    }

    // MARK: - Notification categories (register on launch)

    static func registerCategories() {
        let openAction = UNNotificationAction(identifier: "OPEN", title: "Open Manas", options: .foreground)
        let dismissAction = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: .destructive)

        let highCategory = UNNotificationCategory(
            identifier: "HIGH_RISK",
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        let crisisCategory = UNNotificationCategory(
            identifier: "CRISIS",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([highCategory, crisisCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AlertManager: UNUserNotificationCenterDelegate {
    // Delegate callbacks arrive off the main actor and touch no main-actor state
    // here (one returns presentation options, the other only logs), so they are
    // nonisolated — which also avoids sending non-Sendable UN* types across actors.

    // Show banners even while app is foregrounded
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.content.userInfo["eventId"] as? String
        log.info("Notification response: \(response.actionIdentifier, privacy: .public) eventId: \(id ?? "none", privacy: .public)")
    }
}
