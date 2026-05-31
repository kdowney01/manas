import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var riskEngine: RiskScoringEngine
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                .padding()
            }
            .navigationTitle("manas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: isRefreshing ? "arrow.clockwise.circle" : "arrow.clockwise")
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

private struct RiskStatusCard: View {
    let risk: RiskSeverity
    let score: Double
    let isCalibrating: Bool
    let calibrationProgress: Double

    var body: some View {
        VStack(spacing: 16) {
            if isCalibrating {
                VStack(spacing: 8) {
                    Text("Learning your baseline...")
                        .font(.headline)
                    ProgressView(value: calibrationProgress)
                        .tint(.blue)
                    Text("\(Int(calibrationProgress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Text("Wellbeing Status")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(risk.displayName)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(riskColor)
                    Text("Risk score: \(Int(score * 100))/100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var riskColor: Color {
        switch risk {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .crisis: return .red
        }
    }
}

private struct BiometricGrid: View {
    let snapshot: BiometricSnapshot

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                color: .purple
            )
            MetricTile(
                icon: "bed.double.fill",
                label: "Sleep",
                value: snapshot.sleepHours.map { String(format: "%.1fh", $0) } ?? "--",
                color: .blue
            )
            MetricTile(
                icon: "figure.walk",
                label: "Steps",
                value: snapshot.stepCount.map { "\($0)" } ?? "--",
                color: .green
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RecentEventsSection: View {
    let events: [RiskEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Alerts")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(events) { event in
                HStack {
                    Circle()
                        .fill(eventColor(event.severity))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.severity.displayName)
                            .font(.subheadline.bold())
                        Text(event.triggerSignals.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func eventColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .crisis: return .red
        }
    }
}
