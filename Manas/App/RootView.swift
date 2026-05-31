import SwiftUI

struct RootView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding && healthKitManager.authorizationStatus == .authorized {
            DashboardView()
        } else {
            OnboardingView()
        }
    }
}
