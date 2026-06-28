import SwiftUI

// Faithful SwiftUI port of the HTML prototype's dashboard visual language.
// Sizes, weights, colors and spacing mirror HTML_Prototype/css/styles.css.

// MARK: - Type & color helpers

/// Montserrat at an exact point size (matches the prototype's CSS px values).
func mont(_ size: CGFloat, _ face: String) -> Font { .custom("Montserrat-\(face)", size: size) }

/// Ring/score color by 0–100 — prototype `scoreColor()` (75 / 50 / 30 breakpoints).
func scoreColor(_ score: Int) -> Color {
    switch score {
    case 75...: return RiskSeverity.low.swiftUIColor
    case 50...: return RiskSeverity.moderate.swiftUIColor
    case 30...: return RiskSeverity.high.swiftUIColor
    default:    return RiskSeverity.crisis.swiftUIColor
    }
}

/// Per-signal accent used behind the emoji tile glyph.
func signalTint(_ label: String) -> Color {
    switch label {
    case "Heart Rate":   return RiskSeverity.crisis.swiftUIColor   // red
    case "HRV":          return .manasSecondary                    // lavender
    case "Sleep":        return .manasPrimary                      // indigo
    case "Steps":        return RiskSeverity.low.swiftUIColor      // green
    case "Screen Time":  return .manasPrimary
    case "Social Media": return .manasSecondary
    case "Message Tone": return RiskSeverity.low.swiftUIColor
    case "Email Tone":   return .manasPeach
    default:             return .manasPrimary
    }
}

private extension View {
    /// White card with the prototype's soft shadow.
    func protoCard(_ radius: CGFloat = 16) -> some View {
        background(Color.white, in: RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Score ring

struct ScoreRing: View {
    let score: Int
    let color: Color
    var size: CGFloat = 100

    var body: some View {
        let big = size >= 90
        let lw = size * 8 / 120
        ZStack {
            Circle().stroke(Color.manasSeparator, lineWidth: lw)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)").font(mont(big ? 26 : 24, "ExtraBold")).foregroundStyle(.manasInk)
                if big {
                    Text("OF 100").font(mont(9, "SemiBold")).foregroundStyle(.manasL3).kerning(1)
                }
            }
        }
        .frame(width: size, height: size)
        .padding(lw / 2)
    }
}

// MARK: - Pills & badges

struct WellbeingStatusPill: View {
    let band: RiskSeverity
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(band.swiftUIColor).frame(width: 7, height: 7)
            Text("\(band.displayName) Risk")
        }
        .font(mont(11, "Bold"))
        .foregroundStyle(band.swiftUIColor)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(band.swiftUIBackgroundColor, in: Capsule())
    }
}

/// Orange count badge (prototype `.signal-badge`).
struct WatchBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(mont(11, "ExtraBold")).foregroundStyle(.white)
            .frame(minWidth: 18, minHeight: 18).padding(.horizontal, 5)
            .background(RiskSeverity.high.swiftUIColor, in: Capsule())
    }
}

// MARK: - Big ring card (Overall hero + detail headers)

struct RingScoreCard: View {
    let eyebrow: String
    let score: Int
    let band: RiskSeverity
    let detail: String
    let accent: Color
    var showChevron: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(accent).frame(height: 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(eyebrow.uppercased())
                    .font(mont(10, "SemiBold")).foregroundStyle(.manasL2)
                    .kerning(1.4)
                    .padding(.bottom, 12)
                HStack(spacing: 16) {
                    ScoreRing(score: score, color: band.swiftUIColor, size: 100)
                    VStack(alignment: .leading, spacing: 0) {
                        WellbeingStatusPill(band: band)
                            .padding(.bottom, 8)
                        Text(detail)
                            .font(mont(11, "Regular")).foregroundStyle(.manasL2)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if showChevron {
                        Spacer(minLength: 0)
                        Text("\u{203A}").font(.system(size: 22, weight: .light)).foregroundStyle(.manasL3)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .protoCard()
    }
}

// MARK: - Mini cards (Physio / Digital)

struct MiniScoreCard: View {
    let emoji: String
    let title: String
    let accent: Color
    let score: Int?     // nil → "not set up" state
    let watch: Int

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(accent).frame(height: 3)
            VStack(spacing: 6) {
                HStack {
                    Text("\(emoji) \(title)").font(mont(11, "ExtraBold")).foregroundStyle(accent)
                    Spacer()
                    if watch > 0 { WatchBadge(count: watch) }
                }
                if let score {
                    ScoreRing(score: score, color: scoreColor(score), size: 70)
                        .padding(.vertical, 2)
                    Spacer(minLength: 0)
                    Text("View details \u{203A}").font(mont(11, "SemiBold")).foregroundStyle(.manasL3)
                } else {
                    Text("+").font(.system(size: 30, weight: .light)).foregroundStyle(.manasPrimary)
                        .padding(.vertical, 14)
                    Spacer(minLength: 0)
                    Text("Set up \u{203A}").font(mont(11, "SemiBold")).foregroundStyle(.manasL3)
                }
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 14)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 138)
        .protoCard()
    }
}

// MARK: - Signal tile (emoji + OK/Watch)

struct SignalTile: View {
    let signal: SignalStatus
    private var band: RiskSeverity { signal.isGood ? .low : .high }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack(alignment: .topTrailing) {
                    Text(signal.emoji).font(.system(size: 15))
                        .frame(width: 28, height: 28)
                        .background(signalTint(signal.label).opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                    if !signal.isGood {
                        Circle().fill(RiskSeverity.high.swiftUIColor)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: 3, y: -3)
                    }
                }
                Spacer()
                Text(signal.isGood ? "OK" : "Watch")
                    .font(mont(10, "Bold")).foregroundStyle(band.swiftUIColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(band.swiftUIBackgroundColor, in: RoundedRectangle(cornerRadius: 5))
            }
            Text(signal.value).font(mont(20, "ExtraBold")).foregroundStyle(.manasInk).kerning(-0.5)
            Text(signal.label.uppercased()).font(mont(10, "SemiBold")).foregroundStyle(.manasL3).kerning(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13).padding(.vertical, 14)
        .protoCard(15)
    }
}

// MARK: - Breakdown row (Overall detail)

struct BreakdownRow: View {
    let emoji: String
    let label: String
    let score: Int?

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 20)).frame(width: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(mont(16, "Regular")).foregroundStyle(.manasInk)
                if let score {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.manasSeparator).frame(height: 6)
                            Capsule().fill(scoreColor(score))
                                .frame(width: geo.size.width * CGFloat(score) / 100, height: 6)
                        }
                    }
                    .frame(height: 6).padding(.top, 7)
                }
            }
            if let score {
                Text("\(score)").font(mont(16, "ExtraBold")).foregroundStyle(scoreColor(score))
                    .frame(minWidth: 26, alignment: .trailing)
            } else {
                Text("Not set up").font(mont(12, "Regular")).foregroundStyle(.manasL2)
            }
            Text("\u{203A}").font(.system(size: 17, weight: .regular)).foregroundStyle(.manasL3)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// MARK: - Flagged-area & insight cards

struct FlaggedAreaCard: View {
    let emoji: String
    let title: String
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(mont(14, "Bold")).foregroundStyle(.manasInk)
                Text(tip).font(mont(12, "Regular")).foregroundStyle(.manasL2)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle().fill(RiskSeverity.high.swiftUIColor).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct DailyInsightCard: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("💡").font(.system(size: 14))
                Text("DAILY INSIGHT").font(mont(10, "Bold")).foregroundStyle(.manasPrimary).kerning(0.8)
            }
            Text(text).font(mont(13, "Regular")).foregroundStyle(.manasL2)
                .lineSpacing(2.5).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.manasPrimary).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct RecentAlertsSection: View {
    let events: [RiskEvent]
    var body: some View {
        VStack(spacing: 7) {
            ForEach(events) { event in
                HStack(spacing: 10) {
                    Circle().fill(event.severity.swiftUIColor).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.severity.displayName).font(mont(13, "Bold")).foregroundStyle(.manasInk)
                        Text(event.triggerSignals.joined(separator: " · "))
                            .font(mont(11, "Regular")).foregroundStyle(.manasL2)
                    }
                    Spacer()
                    Text(event.timestamp, style: .relative).font(mont(11, "Regular")).foregroundStyle(.manasL3)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .protoCard(12)
            }
        }
    }
}

// MARK: - Section header (prototype `.section-hd`)

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(mont(13, "SemiBold")).foregroundStyle(.manasL2).kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
    }
}
