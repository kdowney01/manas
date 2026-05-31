import SwiftUI
import HealthKit

@main
struct ManasApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var riskEngine = RiskScoringEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(healthKitManager)
                .environmentObject(riskEngine)
        }
    }
}
