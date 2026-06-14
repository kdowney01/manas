import SwiftUI

// Reusable building blocks for the wellbeing dashboard and its detail screens.
// Visual language matches the existing cards in DashboardView (white card,
// 16pt radius, soft double shadow) plus a thin top accent strip per domain.

// MARK: - Card shell

/// White rounded card with a thin colored top accent strip.
private struct AccentCard<Content: View>: View {
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(accent).frame(height: 3)
            content
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 0)
    }
}

// MARK: - Score ring

struct ScoreRing: View {
    let score: Int
    let color: Color
    var size: CGFloat = 88

    var body: some View {
        let pct = CGFloat(max(0, min(100, score))) / 100
        ZStack {
            Circle().stroke(Color(.systemFill), lineWidth: 8)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                if size >= 84 {
                    Text("OF 100")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .kerning(1)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status pill + watch badge

struct WellbeingStatusPill: View {
    let band: RiskSeverity
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(band.swiftUIColor).frame(width: 6, height: 6)
            Text("\(band.displayName) Risk")
        }
        .font(.manasCaption2).fontWeight(.bold)
        .foregroundStyle(band.swiftUIColor)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(band.swiftUIBackgroundColor, in: Capsule())
    }
}

struct WatchBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.manasCaption2).fontWeight(.heavy)
            .foregroundStyle(.white)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, 5)
            .background(RiskSeverity.high.swiftUIColor, in: Capsule())
    }
}

// MARK: - Dashboard cards

/// Overall hero card on the Today tab.
struct OverallScoreCard: View {
    let score: Int
    let watchCount: Int

    var body: some View {
        let band = Wellbeing.band(for: score)
        AccentCard(accent: .manasPrimary) {
            HStack(spacing: 16) {
                ScoreRing(score: score, color: band.swiftUIColor, size: 88)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Overall Wellbeing")
                        .font(.manasCaption2).fontWeight(.semibold)
                        .foregroundStyle(.secondary).textCase(.uppercase).kerning(0.8)
                    WellbeingStatusPill(band: band)
                    Text(watchSummary)
                        .font(.manasCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(18)
        }
    }

    private var watchSummary: String {
        watchCount > 0
            ? "\(watchCount) area\(watchCount > 1 ? "s" : "") need\(watchCount > 1 ? "" : "s") a closer look."
            : "All signals within your baseline range."
    }
}

/// Compact Physio / Digital card. `score == nil` renders the "not set up" state.
struct MiniScoreCard: View {
    let title: String
    let accent: Color
    let score: Int?
    let watchCount: Int

    var body: some View {
        AccentCard(accent: accent) {
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                        .font(.manasCaption2).fontWeight(.heavy)
                        .foregroundStyle(accent)
                    Spacer()
                    if watchCount > 0 { WatchBadge(count: watchCount) }
                }
                if let score {
                    ScoreRing(score: score, color: Wellbeing.band(for: score).swiftUIColor, size: 68)
                    Text("View details").font(.manasCaption2).foregroundStyle(.tertiary)
                } else {
                    Text("Not set up")
                        .font(.manasCaption).foregroundStyle(.secondary)
                        .frame(height: 68)
                    Text("Set up").font(.manasCaption2).foregroundStyle(.manasPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 14)
        }
    }
}

// MARK: - Detail-screen pieces

/// Big ring + commentary header for a detail screen.
struct ScoreHeaderCard: View {
    let eyebrow: String
    let score: Int
    let commentary: String
    let accent: Color

    var body: some View {
        let band = Wellbeing.band(for: score)
        AccentCard(accent: accent) {
            HStack(spacing: 16) {
                ScoreRing(score: score, color: band.swiftUIColor, size: 88)
                VStack(alignment: .leading, spacing: 7) {
                    Text(eyebrow)
                        .font(.manasCaption2).fontWeight(.semibold)
                        .foregroundStyle(.secondary).textCase(.uppercase).kerning(0.8)
                    WellbeingStatusPill(band: band)
                    Text(commentary)
                        .font(.manasCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }
            .padding(18)
        }
    }
}

struct WellbeingSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.manasCaption).fontWeight(.semibold)
            .foregroundStyle(.secondary).textCase(.uppercase).kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct SignalTile: View {
    let signal: SignalStatus
    private var band: RiskSeverity { signal.isGood ? .low : .high }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: signal.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(signal.isGood ? Color.manasPrimary : RiskSeverity.high.swiftUIColor)
                Spacer()
                Text(signal.isGood ? "OK" : "Watch")
                    .font(.manasCaption2).fontWeight(.bold)
                    .foregroundStyle(band.swiftUIColor)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(band.swiftUIBackgroundColor, in: Capsule())
            }
            Text(signal.value).font(.manasTitle3).foregroundStyle(.primary)
            Text(signal.label)
                .font(.manasCaption).foregroundStyle(.secondary)
                .textCase(.uppercase).kerning(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct BreakdownRow: View {
    let title: String
    let score: Int?

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.manasBody).foregroundStyle(.primary)
            Spacer()
            if let score {
                Text("\(score)")
                    .font(.manasHeadline)
                    .foregroundStyle(Wellbeing.band(for: score).swiftUIColor)
            } else {
                Text("Not set up").font(.manasCaption).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct FlaggedAreaCard: View {
    let signal: SignalStatus
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(RiskSeverity.high.swiftUIColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(signal.label) · \(signal.value)")
                    .font(.manasSubheadline).fontWeight(.semibold)
                Text(tip).font(.manasCaption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(RiskSeverity.high.swiftUIColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
    }
}

struct DailyInsightCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Insight")
                .font(.manasCaption2).fontWeight(.bold)
                .foregroundStyle(.manasPrimary).textCase(.uppercase).kerning(0.5)
            Text("Your signals are tracking close to your personal baseline. Keep an eye on anything flagged above, and talk to your companion any time.")
                .font(.manasFootnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
    }
}

/// Recent risk alerts list (relocated from the dashboard to the Overall detail).
struct RecentAlertsSection: View {
    let events: [RiskEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(events) { event in
                HStack(spacing: 12) {
                    Circle().fill(event.severity.swiftUIColor).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.severity.displayName)
                            .font(.manasSubheadline).fontWeight(.semibold)
                        Text(event.triggerSignals.joined(separator: " · "))
                            .font(.manasCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.timestamp, style: .relative)
                        .font(.manasCaption2).foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
            }
        }
    }
}
