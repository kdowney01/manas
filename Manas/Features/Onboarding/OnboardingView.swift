import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0

    var body: some View {
        switch currentStep {
        case 0: WelcomeStep(onNext: { currentStep = 1 })
        case 1: HealthKitPermissionStep(onNext: { currentStep = 2 })
        case 2: CalibrationInfoStep(onDone: { hasCompletedOnboarding = true })
        default: EmptyView()
        }
    }
}

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("manas")
                .font(.system(size: 48, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)

            Text("Every mind deserves care,\nbecause silence should never be a sentence.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Text("Manas passively monitors your wellbeing using health data already collected by your iPhone.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Text("No cameras. No microphones. Just the signals your body already shares.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 32)
            }

            Button("Get Started", action: onNext)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 48)
        }
    }
}

private struct HealthKitPermissionStep: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    let onNext: () -> Void
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Health Access")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(icon: "heart.fill", label: "Heart Rate & HRV", description: "Detect stress patterns")
                PermissionRow(icon: "bed.double.fill", label: "Sleep", description: "Track rest quality")
                PermissionRow(icon: "figure.walk", label: "Activity", description: "Monitor behavioral changes")
            }
            .padding(.horizontal, 32)

            Text("All health data is processed on your device. Nothing is shared without your permission.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            Button(isRequesting ? "Requesting..." : "Allow Health Access") {
                isRequesting = true
                Task {
                    await healthKitManager.requestAuthorization()
                    isRequesting = false
                    if healthKitManager.authorizationStatus == .authorized {
                        onNext()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(.bottom, 48)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct CalibrationInfoStep: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Learning Your Baseline")
                .font(.title2.bold())

            Text("For the first 7 days, Manas quietly learns what's normal for you. After that, it can spot meaningful changes.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Text("You'll see a status indicator, but risk scoring won't activate until your personal baseline is established.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 32)

            Spacer()

            Button("Start Manas", action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 48)
        }
    }
}
