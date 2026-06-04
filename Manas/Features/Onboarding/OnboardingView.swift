import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var contactStore: EmergencyContactStore
    @EnvironmentObject var alertManager: AlertManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step = 0

    var body: some View {
        switch step {
        case 0: WelcomeStep       { step = 1 }
        case 1: HealthKitStep     { step = 2 }
        case 2: EmergencyStep     { step = 3 }
        case 3: NotificationsStep { step = 4 }
        case 4: CalibrationStep   { hasCompletedOnboarding = true }
        default: EmptyView()
        }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            if let logo = UIImage(named: "manas_logo") ?? UIImage(contentsOfFile: logoPath) {
                Image(uiImage: logo)
                    .resizable().scaledToFit()
                    .frame(width: 160)
            } else {
                Text("manas")
                    .font(.manasWordmark)
                    .foregroundStyle(.manasPrimary)
            }

            VStack(spacing: 12) {
                Text("Manas passively monitors your wellbeing using health data already collected by your iPhone.")
                    .font(.manasSubheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Text("Private · Always-on · On-device")
                    .font(.manasCaption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Get Started", action: onNext)
                    .buttonStyle(ManasButtonStyle())
                    .padding(.horizontal, 32)

                Text("By continuing you agree to our Privacy Policy and Terms of Service.")
                    .font(.manasCaption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 48)
        }
    }

    private var logoPath: String {
        Bundle.main.path(forResource: "manas_logo", ofType: "png") ?? ""
    }
}

// MARK: - Step 1: HealthKit

private struct HealthKitStep: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    let onNext: () -> Void
    @State private var isRequesting = false

    var body: some View {
        OnboardingShell(
            icon: "heart.text.square.fill",
            iconColor: .red,
            title: "Health Access",
            subtitle: "Manas reads signals already on your iPhone. Nothing is sent anywhere without your permission.",
            onNext: requestAccess,
            nextLabel: isRequesting ? "Requesting…" : "Allow Health Access",
            nextDisabled: isRequesting,
            stepText: "Step 1 of 4"
        ) {
            VStack(spacing: 8) {
                PermissionRow(icon: "heart.fill",     color: .red,         label: "Heart Rate & HRV",  detail: "Stress detection")
                PermissionRow(icon: "moon.fill",      color: .manasPrimary, label: "Sleep",             detail: "Recovery patterns")
                PermissionRow(icon: "figure.walk",    color: .green,       label: "Activity",          detail: "Behavioral changes")
            }
            Text("All processing is on-device. Raw HealthKit data never leaves your iPhone.")
                .font(.manasCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            await healthKitManager.requestAuthorization()
            isRequesting = false
            if healthKitManager.authorizationStatus == .authorized { onNext() }
        }
    }
}

// MARK: - Step 2: Emergency Contacts

private struct EmergencyStep: View {
    @EnvironmentObject var contactStore: EmergencyContactStore
    let onNext: () -> Void
    @State private var name = ""
    @State private var phone = ""
    @State private var relationship = ""
    @State private var skipped = false

    var body: some View {
        OnboardingShell(
            icon: "person.2.fill",
            iconColor: .manasPrimary,
            title: "Emergency Contacts",
            subtitle: "If Manas detects a crisis, it can alert someone you trust. You can add or change contacts anytime.",
            onNext: saveAndContinue,
            nextLabel: name.isEmpty ? "Skip for now" : "Save & Continue",
            stepText: "Step 2 of 4"
        ) {
            VStack(spacing: 12) {
                TextField("Contact name", text: $name)
                    .textContentType(.name)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                TextField("Phone number", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                TextField("Relationship (e.g. Parent, Friend)", text: $relationship)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .font(.manasBody)
            .padding(.horizontal, 4)

            Text("Contact info is encrypted and stored only in your device Keychain. It is never uploaded.")
                .font(.manasCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func saveAndContinue() {
        if !name.isEmpty, !phone.isEmpty {
            contactStore.add(EmergencyContact(
                name: name, phoneNumber: phone,
                relationship: relationship.isEmpty ? "Contact" : relationship
            ))
        }
        onNext()
    }
}

// MARK: - Step 3: Notifications

private struct NotificationsStep: View {
    @EnvironmentObject var alertManager: AlertManager
    let onNext: () -> Void

    var body: some View {
        OnboardingShell(
            icon: "bell.badge.fill",
            iconColor: .manasSecondary,
            title: "Stay Informed",
            subtitle: "Manas sends gentle nudges when your signals shift, and critical alerts during a crisis — no noise otherwise.",
            onNext: requestAndContinue,
            nextLabel: "Enable Notifications",
            stepText: "Step 3 of 4"
        ) {
            VStack(spacing: 8) {
                PermissionRow(icon: "bell",        color: .manasSecondary, label: "Wellbeing nudges",  detail: "Gentle check-in at High risk")
                PermissionRow(icon: "exclamationmark.triangle.fill", color: .red, label: "Crisis alerts", detail: "Immediate support at Crisis level")
            }
            Button("Skip for now") { onNext() }
                .font(.manasCaption)
                .foregroundStyle(.secondary)
        }
    }

    private func requestAndContinue() {
        Task {
            await alertManager.requestAuthorization()
            onNext()
        }
    }
}

// MARK: - Step 4: Calibration

private struct CalibrationStep: View {
    let onDone: () -> Void

    var body: some View {
        OnboardingShell(
            icon: "waveform.path.ecg",
            iconColor: .manasPrimary,
            title: "Learning Your Baseline",
            subtitle: "For 7 days Manas learns what's normal for you. Risk scoring activates automatically after that.",
            onNext: onDone,
            nextLabel: "Start Manas",
            stepText: "Step 4 of 4"
        ) {
            HStack(spacing: 6) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day == "M" ? Color.manasPrimary : Color(.secondarySystemBackground))
                            .overlay(
                                Text(day == "M" ? "✓" : day)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(day == "M" ? .white : Color.secondary)
                            )
                            .frame(width: 32, height: 32)
                    }
                }
            }
            Text("No action needed — Manas works quietly in the background.")
                .font(.manasCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Reusable shell

private struct OnboardingShell<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let onNext: () -> Void
    let nextLabel: String
    var nextDisabled: Bool = false
    let stepText: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(iconColor)

            VStack(spacing: 8) {
                Text(title).font(.manasTitle2)
                Text(subtitle).font(.manasSubheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
            }

            content.padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                Text(stepText).font(.manasCaption2).foregroundStyle(.tertiary)
                Button(nextLabel, action: onNext)
                    .buttonStyle(ManasButtonStyle())
                    .disabled(nextDisabled)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Permission row

private struct PermissionRow: View {
    let icon: String
    let color: Color
    let label: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.manasSubheadline).fontWeight(.semibold)
                Text(detail).font(.manasCaption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Button style

struct ManasButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.manasHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(isEnabled ? Color.manasPrimary : Color.secondary, in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
