import Foundation
import OSLog

// DeviceActivity (Screen Time API) integration.
//
// ENTITLEMENT REQUIRED: com.apple.developer.family-controls
// This entitlement requires explicit Apple approval. Request it at:
//   https://developer.apple.com/contact/request/family-controls-distribution
//
// Until approved, this class operates in stub mode and returns no anomaly data.
// All aggregation happens on-device; only the boolean anomaly flag (+ category)
// is ever surfaced to the rest of the app. Raw app usage data never leaves the device.
//
// To activate: uncomment the DeviceActivity imports below and add the entitlement.

private let log = Logger(subsystem: "com.manas.app", category: "DeviceActivityMonitor")

// MARK: - Anomaly output (what this class exposes to the risk engine)

struct AppUsageAnomaly {
    enum Category: String {
        case excessiveSocialMedia   = "excessive_social_media"
        case unusualHours           = "unusual_hours"
        case communicationDrop      = "communication_drop"
        case overallReduction       = "overall_reduction"
    }
    let detected: Bool
    let categories: [Category]
    let timestamp: Date
}

// MARK: - Monitor

@MainActor
final class DeviceActivityMonitor: ObservableObject {
    static let shared = DeviceActivityMonitor()

    @Published private(set) var latestAnomaly: AppUsageAnomaly?
    @Published private(set) var isAuthorized = false

    // Baseline: rolling 7-day average per category (stored locally, not transmitted)
    private var baselineSocialMediaMinutes: Double = 0
    private var baselineCommunicationMinutes: Double = 0

    private init() {}

    // MARK: - Authorization
    // Requires FamilyControls entitlement. Call during onboarding.

    func requestAuthorization() async {
        // Activation path (uncomment once FamilyControls entitlement is approved):
        //
        // import FamilyControls
        // do {
        //     try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        //     isAuthorized = true
        //     log.info("FamilyControls authorized")
        // } catch {
        //     log.error("FamilyControls authorization failed: \(error.localizedDescription, privacy: .public)")
        // }
        //
        // Until entitlement approved (apply at apple.com/contact/request/family-controls-distribution):
        log.info("DeviceActivity authorization requested — entitlement pending Apple approval")
        isAuthorized = false
    }

    // MARK: - Monitoring lifecycle

    func startMonitoring() {
        guard isAuthorized else {
            log.info("DeviceActivity monitoring skipped — not authorized")
            return
        }
        // Activation path (uncomment with FamilyControls):
        //
        // import DeviceActivity
        // let schedule = DeviceActivitySchedule(
        //     intervalStart: DateComponents(hour: 0, minute: 0),
        //     intervalEnd:   DateComponents(hour: 23, minute: 59),
        //     repeats: true
        // )
        // let center = DeviceActivityCenter()
        // try? center.startMonitoring(.daily, during: schedule)
        log.info("DeviceActivity monitoring ready — activate after entitlement provisioned")
    }

    func stopMonitoring() {
        // DeviceActivityCenter().stopMonitoring()
        log.info("DeviceActivity monitoring stopped")
    }

    // MARK: - Anomaly evaluation
    // Called on a schedule or when DeviceActivityReport data is available.
    // Only works with the entitlement; otherwise returns no anomaly.

    func evaluateUsage(socialMediaMinutes: Double,
                       communicationMinutes: Double,
                       sessionStartHour: Int) {
        guard isAuthorized else { return }

        var categories: [AppUsageAnomaly.Category] = []

        // Excessive social media: >2x personal baseline
        if baselineSocialMediaMinutes > 0,
           socialMediaMinutes > baselineSocialMediaMinutes * 2 {
            categories.append(.excessiveSocialMedia)
        }

        // Unusual hours: active between midnight–5am
        if (0...5).contains(sessionStartHour) {
            categories.append(.unusualHours)
        }

        // Communication drop: <30% of personal baseline
        if baselineCommunicationMinutes > 0,
           communicationMinutes < baselineCommunicationMinutes * 0.30 {
            categories.append(.communicationDrop)
        }

        let anomaly = AppUsageAnomaly(
            detected: !categories.isEmpty,
            categories: categories,
            timestamp: Date()
        )
        latestAnomaly = anomaly

        if anomaly.detected {
            log.info("App usage anomaly detected: \(categories.map(\.rawValue).joined(separator: ", "), privacy: .public)")
        }
    }

    // MARK: - Baseline update (called after calibration period)

    func updateBaseline(socialMediaMinutes: Double, communicationMinutes: Double) {
        baselineSocialMediaMinutes = socialMediaMinutes
        baselineCommunicationMinutes = communicationMinutes
        log.info("DeviceActivity baseline updated")
    }
}
