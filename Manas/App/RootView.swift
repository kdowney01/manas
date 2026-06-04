import SwiftUI

struct RootView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var alertManager: AlertManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding && healthKitManager.authorizationStatus == .authorized {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $alertManager.activeCrisisEvent) { event in
            NavigationStack {
                CrisisView(event: event)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { alertManager.clearCrisis() }
                        }
                    }
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "heart.text.square.fill") }

            CompanionView()
                .tabItem { Label("Companion", systemImage: "bubble.left.and.bubble.right.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.manasPrimary)
    }
}
