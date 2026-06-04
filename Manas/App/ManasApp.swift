import SwiftUI
import UIKit

@main
struct ManasApp: App {
    @StateObject private var healthKitManager   = HealthKitManager()
    @StateObject private var riskEngine         = RiskScoringEngine()
    @StateObject private var alertManager       = AlertManager.shared
    @StateObject private var contactStore       = EmergencyContactStore()
    @StateObject private var deviceActivity     = DeviceActivityMonitor.shared
    @StateObject private var backend            = BackendService.shared
    @StateObject private var emotionAnalyzer    = FacialEmotionAnalyzer()

    init() {
        applyBrandAppearance()
        AlertManager.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(healthKitManager)
                .environmentObject(riskEngine)
                .environmentObject(alertManager)
                .environmentObject(contactStore)
                .environmentObject(deviceActivity)
                .environmentObject(backend)
                .environmentObject(emotionAnalyzer)
                .tint(.manasPrimary)
        }
    }

    // MARK: - Brand appearance (Montserrat nav bar)

    private func applyBrandAppearance() {
        let indigo = UIColor(red: 92/255, green: 108/255, blue: 179/255, alpha: 1)
        let bold     = UIFont(name: "Montserrat-Bold",     size: 34) ?? .systemFont(ofSize: 34, weight: .bold)
        let semibold = UIFont(name: "Montserrat-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [.font: bold,     .foregroundColor: indigo]
        appearance.titleTextAttributes      = [.font: semibold, .foregroundColor: indigo]

        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
    }
}
