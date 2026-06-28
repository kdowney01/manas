import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var riskEngine: RiskScoringEngine
    @EnvironmentObject var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.todayPath) {
            ScrollView {
                VStack(spacing: 10) {
                    greeting

                    if !riskEngine.userProfile.calibrationComplete {
                        CalibrationCard(progress: calibrationProgress)
                    } else {
                        NavigationLink(value: WellbeingRoute.overall) {
                            OverallScoreCard(score: riskEngine.overallWellbeing, watchCount: totalWatchCount)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 10) {
                            NavigationLink(value: WellbeingRoute.physio) {
                                MiniScoreCard(emoji: "❤️", title: "Physio", accent: .manasSecondary,
                                              score: riskEngine.physioWellbeing, watch: physioWatchCount)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: WellbeingRoute.digital) {
                                MiniScoreCard(emoji: "📲", title: "Digital", accent: .manasSecondary,
                                              score: riskEngine.digitalWellbeing, watch: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.manasBackground.ignoresSafeArea())
            .navigationDestination(for: WellbeingRoute.self) { route in
                switch route {
                case .overall: OverallDetailView()
                case .physio:  PhysioDetailView()
                case .digital: DigitalDetailView()
                }
            }
            .toolbar { navToolbar }
            .navigationBarTitleDisplayMode(.inline)
            .task { await refresh() }
        }
    }

    // Prototype top bar: logo left, hamburger right.
    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Image(uiImage: UIImage(named: "manas_logo") ?? UIImage())
                .resizable().scaledToFit().frame(height: 26)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.openMenu() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.manasInk)
            }
        }
    }

    // Prototype greeting.
    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Good morning, Kyle 👋").font(mont(13, "SemiBold")).foregroundStyle(.manasL2)
            Text("\(Self.dateString) · Updated just now").font(mont(11, "Regular")).foregroundStyle(.manasL3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var calibrationProgress: Double {
        let samples = riskEngine.userProfile.calibrationSampleCount
        return min(Double(samples) / Double(UserProfile.calibrationTargetSamples), 1.0)
    }
    private var physioWatchCount: Int { riskEngine.physioSignals().filter { !$0.isGood }.count }
    private var totalWatchCount: Int { physioWatchCount }   // + Digital in Phase 2

    private func refresh() async {
        await healthKitManager.fetchLatestSnapshot()
        if let snapshot = healthKitManager.latestSnapshot {
            riskEngine.process(snapshot)
        }
    }
}

// MARK: - Overall hero card (tappable)

struct OverallScoreCard: View {
    let score: Int
    let watchCount: Int

    var body: some View {
        RingScoreCard(
            eyebrow: "Overall Wellbeing",
            score: score,
            band: Wellbeing.band(for: score),
            detail: watchCount > 0
                ? "\(watchCount) area\(watchCount > 1 ? "s" : "") need\(watchCount > 1 ? "" : "s") a closer look."
                : "All signals within your baseline range.",
            accent: .manasPrimary,
            showChevron: true
        )
    }
}

// MARK: - Calibration card (until the 7-day baseline is established)

private struct CalibrationCard: View {
    let progress: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📈 LEARNING YOUR BASELINE").font(mont(10, "Bold")).foregroundStyle(.manasPrimary).kerning(0.8)
            ProgressView(value: progress).tint(.manasPrimary)
            Text("\(Int(progress * 100))% of 7-day calibration complete")
                .font(mont(12, "Regular")).foregroundStyle(.manasL2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

#if DEBUG
#Preview {
    DashboardView()
        .environmentObject(RiskScoringEngine.preview())
        .environmentObject(HealthKitManager())
        .environmentObject(AppRouter())
}
#endif
