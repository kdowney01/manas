import SwiftUI

/// App-wide navigation state: selected tab, the Today tab's push stack, and the
/// hamburger menu. Lets the side-drawer drive navigation across tabs.
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case today, companion, settings }

    @Published var tab: Tab = .today
    @Published var todayPath: [WellbeingRoute] = []
    @Published var showMenu = false

    func openMenu()  { withAnimation(.easeOut(duration: 0.28)) { showMenu = true } }
    func closeMenu() { withAnimation(.easeOut(duration: 0.22)) { showMenu = false } }

    func goHome() { tab = .today; todayPath = []; closeMenu() }
    func goTab(_ t: Tab) { tab = t; closeMenu() }
    func goDetail(_ route: WellbeingRoute) { tab = .today; todayPath = [route]; closeMenu() }
}

// MARK: - Side-drawer menu (prototype hamburger)

struct MenuDrawer: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var alertManager: AlertManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(router.showMenu ? 0.38 : 0)
                .ignoresSafeArea()
                .onTapGesture { router.closeMenu() }

            VStack(alignment: .leading, spacing: 0) {
                // Head: logo + close
                HStack {
                    logo.frame(height: 28)
                    Spacer()
                    Button { router.closeMenu() } label: {
                        Text("×").font(.system(size: 18))
                            .foregroundStyle(.manasL2)
                            .frame(width: 30, height: 30)
                            .background(Color.manasBackground, in: Circle())
                    }
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)
                .overlay(alignment: .bottom) { Divider() }

                // Links
                VStack(spacing: 0) {
                    row("Today")            { router.goHome() }
                    row("Overall Wellbeing"){ router.goDetail(.overall) }
                    row("Physio Wellbeing") { router.goDetail(.physio) }
                    row("Digital Wellbeing"){ router.goDetail(.digital) }
                    row("Companion")        { router.goTab(.companion) }
                    row("Settings")         { router.goTab(.settings) }
                    Divider().padding(.horizontal, 20).padding(.vertical, 8)
                    row("Get Help Now", icon: "⚠️", color: RiskSeverity.crisis.swiftUIColor) { getHelp() }
                    row("Privacy")          { router.goTab(.settings) }
                    row("Sign Out", color: .manasL2, weight: "Medium") { signOut() }
                }
                .padding(.vertical, 10)

                Spacer()
            }
            .frame(width: 290)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.white.ignoresSafeArea())
            .shadow(color: .black.opacity(0.22), radius: 15, x: -8, y: 0)
            .offset(x: router.showMenu ? 0 : 330)
        }
        .allowsHitTesting(router.showMenu)
    }

    private var logo: some View {
        Image(uiImage: UIImage(named: "manas_logo") ?? UIImage())
            .resizable().scaledToFit()
    }

    private func row(_ label: String, icon: String? = nil,
                     color: Color = .manasInk, weight: String = "SemiBold",
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon { Text(icon).font(.system(size: 18)).frame(width: 24) }
                Text(label).font(mont(16, weight)).foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func getHelp() {
        router.closeMenu()
        alertManager.activeCrisisEvent = RiskEvent(severity: .crisis, triggerSignals: [], riskScore: 1.0)
    }

    private func signOut() {
        hasCompletedOnboarding = false
        router.goHome()
    }
}
