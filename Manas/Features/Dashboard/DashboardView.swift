import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var riskEngine: RiskScoringEngine
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greeting

                    if !riskEngine.userProfile.calibrationComplete {
                        CalibrationCard(progress: calibrationProgress)
                    } else {
                        NavigationLink(value: WellbeingRoute.overall) {
                            OverallScoreCard(score: riskEngine.overallWellbeing, watchCount: totalWatchCount)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            NavigationLink(value: WellbeingRoute.physio) {
                                MiniScoreCard(title: "Physio", accent: .manasSecondary,
                                              score: riskEngine.physioWellbeing, watchCount: physioWatchCount)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: WellbeingRoute.digital) {
                                MiniScoreCard(title: "Digital", accent: .manasSecondary,
                                              score: riskEngine.digitalWellbeing, watchCount: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.manasBackground.ignoresSafeArea())
            .navigationTitle("manas")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: WellbeingRoute.self) { route in
                switch route {
                case .overall: OverallDetailView()
                case .physio:  PhysioDetailView()
                case .digital: DigitalDetailView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: isRefreshing ? "arrow.clockwise.circle" : "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(isRefreshing)
                }
            }
            .task { await refresh() }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Good morning")
                .font(.manasCaption).foregroundStyle(.secondary)
            Text(Date(), style: .date)
                .font(.manasCaption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calibrationProgress: Double {
        let samples = riskEngine.userProfile.calibrationSampleCount
        let target = UserProfile.calibrationTargetSamples
        return min(Double(samples) / Double(target), 1.0)
    }

    private var physioWatchCount: Int {
        riskEngine.physioSignals().filter { !$0.isGood }.count
    }

    private var totalWatchCount: Int {
        physioWatchCount  // + Digital watch count in Phase 2
    }

    private func refresh() async {
        isRefreshing = true
        await healthKitManager.fetchLatestSnapshot()
        if let snapshot = healthKitManager.latestSnapshot {
            riskEngine.process(snapshot)
        }
        isRefreshing = false
    }
}

// MARK: - Calibration card (shown until the 7-day baseline is established)

private struct CalibrationCard: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Learning your baseline", systemImage: "chart.line.uptrend.xyaxis")
                .font(.manasHeadline)
                .foregroundStyle(.manasPrimary)
            ProgressView(value: progress)
                .tint(.manasPrimary)
            Text("\(Int(progress * 100))% of 7-day calibration complete")
                .font(.manasCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 0)
    }
}

#if DEBUG
#Preview {
    DashboardView()
        .environmentObject(RiskScoringEngine.preview())
        .environmentObject(HealthKitManager())
}
#endif
