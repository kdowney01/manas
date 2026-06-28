import SwiftUI

struct RootView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var alertManager: AlertManager
    @EnvironmentObject var router: AppRouter
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding && healthKitManager.authorizationStatus == .authorized {
                mainTabs
                MenuDrawer().zIndex(2)
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
        TabView(selection: $router.tab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "heart.text.square.fill") }
                .tag(AppRouter.Tab.today)

            CompanionView()
                .tabItem { Label("Companion", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppRouter.Tab.companion)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(.manasPrimary)
    }
}
