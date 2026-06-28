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
            VStack(spacing: 12) {
                RingScoreCard(
                    eyebrow: "Overall Wellbeing",
                    score: score,
                    band: Wellbeing.band(for: score),
                    detail: Wellbeing.overallCommentary(score),
                    accent: .manasPrimary
                )

                section("Breakdown") {
                    VStack(spacing: 0) {
                        NavigationLink(value: WellbeingRoute.physio) {
                            BreakdownRow(emoji: "❤️", label: "Physio Wellbeing", score: riskEngine.physioWellbeing)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                        NavigationLink(value: WellbeingRoute.digital) {
                            BreakdownRow(emoji: "📲", label: "Digital Wellbeing", score: riskEngine.digitalWellbeing)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }

                section("Daily Insight") {
                    DailyInsightCard(text: "Your signals are tracking close to your personal baseline. Keep an eye on anything flagged, and talk to your companion any time.")
                }

                if !riskEngine.recentEvents.isEmpty {
                    section("Recent Alerts") {
                        RecentAlertsSection(events: Array(riskEngine.recentEvents.prefix(5)))
                    }
                }
            }
            .padding(.horizontal, 14)
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
            VStack(spacing: 12) {
                RingScoreCard(
                    eyebrow: "Physio Wellbeing",
                    score: score,
                    band: Wellbeing.band(for: score),
                    detail: Wellbeing.physioCommentary(score),
                    accent: .manasSecondary
                )

                if signals.isEmpty {
                    Text("No biometric data yet. Refresh on the Today tab once Health data is available.")
                        .font(mont(13, "Regular")).foregroundStyle(.manasL2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    section("Signals") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                            ForEach(signals) { SignalTile(signal: $0) }
                        }
                    }
                    if !flags.isEmpty {
                        section("Needs attention") {
                            VStack(spacing: 8) {
                                ForEach(flags) { s in
                                    FlaggedAreaCard(emoji: s.emoji, title: "\(s.label) · \(s.value)",
                                                    tip: Wellbeing.physioTip(forLabel: s.label))
                                }
                            }
                        }
                    }
                }

                Text("Scores compare today's readings to your personal baseline. All processing happens on-device.")
                    .font(mont(11, "Regular")).foregroundStyle(.manasL3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 14)
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
            VStack(spacing: 10) {
                Text("📲").font(.system(size: 40))
                Text("Digital signals aren't set up yet")
                    .font(mont(17, "Bold")).foregroundStyle(.manasInk)
                    .multilineTextAlignment(.center)
                Text("Digital wellbeing — screen time, social use, and message tone — will be available to enable during setup.")
                    .font(mont(13, "Regular")).foregroundStyle(.manasL2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.manasBackground.ignoresSafeArea())
        .navigationTitle("Digital Wellbeing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Section header + content with prototype spacing.
@ViewBuilder
private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        SectionLabel(title)
        content()
    }
}

#if DEBUG
#Preview("Overall") {
    NavigationStack { OverallDetailView() }.environmentObject(RiskScoringEngine.preview())
}
#Preview("Physio") {
    NavigationStack { PhysioDetailView() }.environmentObject(RiskScoringEngine.preview())
}
#Preview("Digital") {
    NavigationStack { DigitalDetailView() }
}
#endif
