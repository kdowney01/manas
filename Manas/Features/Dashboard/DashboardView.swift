import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var riskEngine: RiskScoringEngine
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RiskStatusCard(
                        risk: riskEngine.currentRisk,
                        score: riskEngine.currentScore,
                        isCalibrating: !riskEngine.userProfile.calibrationComplete,
                        calibrationProgress: calibrationProgress
                    )

                    if let snapshot = healthKitManager.latestSnapshot {
                        BiometricGrid(snapshot: snapshot)
                    }

                    if !riskEngine.recentEvents.isEmpty {
                        RecentEventsSection(events: Array(riskEngine.recentEvents.prefix(5)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.manasBackground.ignoresSafeArea())
            .navigationTitle("manas")
            .navigationBarTitleDisplayMode(.large)
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

    private var calibrationProgress: Double {
        let samples = riskEngine.userProfile.calibrationSampleCount
        let target = UserProfile.calibrationTargetSamples
        return min(Double(samples) / Double(target), 1.0)
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

// MARK: - Risk Status Card

private struct RiskStatusCard: View {
    let risk: RiskSeverity
    let score: Double
    let isCalibrating: Bool
    let calibrationProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isCalibrating {
                calibratingContent
            } else {
                activeContent
            }
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 0)
    }

    private var calibratingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Learning your baseline", systemImage: "chart.line.uptrend.xyaxis")
                .font(.manasHeadline)
                .foregroundStyle(.manasPrimary)
            ProgressView(value: calibrationProgress)
                .tint(.manasPrimary)
            Text("\(Int(calibrationProgress * 100))% of 7-day calibration complete")
                .font(.manasCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wellbeing Status")
                .font(.manasCaption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .bottom) {
                Text(risk.displayName)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(risk.swiftUIColor)

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Risk score: \(Int(score * 100))/100")
                        .font(.manasCaption)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemFill))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(risk.swiftUIColor)
                                .frame(width: geo.size.width * score, height: 5)
                        }
                    }
                    .frame(width: 80, height: 5)
                }
            }

            // Status tags
            HStack(spacing: 6) {
                RiskTag(label: risk.statusSummary, color: risk.swiftUIColor)
            }
        }
    }
}

// MARK: - Risk Tag

private struct RiskTag: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.manasCaption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

private extension RiskSeverity {
    var statusSummary: String {
        switch self {
        case .low:      return "All signals normal"
        case .moderate: return "Some signals elevated"
        case .high:     return "Multiple signals elevated"
        case .crisis:   return "Immediate attention needed"
        }
    }
}

// MARK: - Biometric Grid

private struct BiometricGrid: View {
    let snapshot: BiometricSnapshot

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            MetricTile(
                icon: "heart.fill",
                label: "Heart Rate",
                value: snapshot.heartRate.map { "\(Int($0)) BPM" } ?? "--",
                color: .red
            )
            MetricTile(
                icon: "waveform.path.ecg",
                label: "HRV",
                value: snapshot.hrv.map { "\(Int($0)) ms" } ?? "--",
                color: .manasSecondary
            )
            MetricTile(
                icon: "moon.fill",
                label: "Sleep",
                value: snapshot.sleepHours.map { String(format: "%.1fh", $0) } ?? "--",
                color: .manasPrimary
            )
            MetricTile(
                icon: "figure.walk",
                label: "Steps",
                value: snapshot.stepCount.map { "\($0)" } ?? "--",
                color: Color(red: 52/255, green: 199/255, blue: 89/255)
            )
        }
    }
}

private struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.manasTitle3)
                .foregroundStyle(.primary)
            Text(label)
                .font(.manasCaption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 0)
    }
}

// MARK: - Recent Events

private struct RecentEventsSection: View {
    let events: [RiskEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Alerts")
                .font(.manasHeadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            ForEach(events) { event in
                HStack(spacing: 12) {
                    Circle()
                        .fill(event.severity.swiftUIColor)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.severity.displayName)
                            .font(.manasSubheadline)
                            .fontWeight(.semibold)
                        Text(event.triggerSignals.joined(separator: " · "))
                            .font(.manasCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.timestamp, style: .relative)
                        .font(.manasCaption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
            }
        }
    }
}
