import SwiftUI

/// Drill-down destinations from the three Today cards.
enum WellbeingRoute: Hashable {
    case overall
    case physio
    case digital
}

// MARK: - Overall

struct OverallDetailView: View {
    @EnvironmentObject var riskEngine: RiskScoringEngine

    var body: some View {
        let score = riskEngine.overallWellbeing
        ScrollView {
            VStack(spacing: 16) {
                ScoreHeaderCard(
                    eyebrow: "Overall Wellbeing",
                    score: score,
                    commentary: Wellbeing.overallCommentary(score),
                    accent: .manasPrimary
                )

                VStack(alignment: .leading, spacing: 8) {
                    WellbeingSectionHeader("Breakdown")
                    VStack(spacing: 0) {
                        NavigationLink(value: WellbeingRoute.physio) {
                            BreakdownRow(title: "Physio Wellbeing", score: riskEngine.physioWellbeing)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                        NavigationLink(value: WellbeingRoute.digital) {
                            BreakdownRow(title: "Digital Wellbeing", score: riskEngine.digitalWellbeing)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    WellbeingSectionHeader("Daily Insight")
                    DailyInsightCard()
                }

                if !riskEngine.recentEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        WellbeingSectionHeader("Recent Alerts")
                        RecentAlertsSection(events: Array(riskEngine.recentEvents.prefix(5)))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.manasBackground.ignoresSafeArea())
        .navigationTitle("Overall Wellbeing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Physio

struct PhysioDetailView: View {
    @EnvironmentObject var riskEngine: RiskScoringEngine

    var body: some View {
        let score = riskEngine.physioWellbeing
        let signals = riskEngine.physioSignals()
        let flags = signals.filter { !$0.isGood }
        ScrollView {
            VStack(spacing: 16) {
                ScoreHeaderCard(
                    eyebrow: "Physio Wellbeing",
                    score: score,
                    commentary: Wellbeing.physioCommentary(score),
                    accent: .manasSecondary
                )

                if signals.isEmpty {
                    Text("No biometric data yet. Refresh on the Today tab once Health data is available.")
                        .font(.manasFootnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        WellbeingSectionHeader("Signals")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(signals) { SignalTile(signal: $0) }
                        }
                    }

                    if !flags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            WellbeingSectionHeader("Needs attention")
                            ForEach(flags) { signal in
                                FlaggedAreaCard(signal: signal, tip: Wellbeing.physioTip(forLabel: signal.label))
                            }
                        }
                    }
                }

                Text("Scores compare today's readings to your personal baseline. All processing happens on-device.")
                    .font(.manasCaption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.manasBackground.ignoresSafeArea())
        .navigationTitle("Physio Wellbeing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Digital (Phase 1 placeholder; populated in Phase 2)

struct DigitalDetailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Text("Digital signals aren't set up yet")
                        .font(.manasTitle3)
                        .multilineTextAlignment(.center)
                    Text("Digital wellbeing — screen time, social use, and message tone — will be available to enable during setup.")
                        .font(.manasFootnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.manasBackground.ignoresSafeArea())
        .navigationTitle("Digital Wellbeing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Overall") {
    NavigationStack { OverallDetailView() }
        .environmentObject(RiskScoringEngine.preview())
}

#Preview("Physio") {
    NavigationStack { PhysioDetailView() }
        .environmentObject(RiskScoringEngine.preview())
}

#Preview("Digital") {
    NavigationStack { DigitalDetailView() }
}
#endif
