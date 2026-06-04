import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var contactStore: EmergencyContactStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var alertManager: AlertManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showAddContact = false
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                emergencyContactsSection
                notificationsSection
                privacySection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddContact) {
                AddContactSheet { contactStore.add($0) }
            }
            .confirmationDialog(
                "Delete All Data",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All My Data", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all your health baselines, risk history, and personal settings from this device. This cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Sections

    private var emergencyContactsSection: some View {
        Section {
            ForEach(contactStore.contacts) { contact in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.manasSubheadline).fontWeight(.semibold)
                        Text("\(contact.relationship) · \(contact.phoneNumber)")
                            .font(.manasCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if contact.notifyAtHighRisk {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.manasPrimary)
                    }
                }
            }
            .onDelete { contactStore.delete(at: $0) }

            Button {
                showAddContact = true
            } label: {
                Label("Add Emergency Contact", systemImage: "plus.circle.fill")
                    .foregroundStyle(.manasPrimary)
            }
        } header: {
            Text("Emergency Contacts")
        } footer: {
            Text("Contacts are alerted via SMS during a crisis. Stored securely in your device Keychain.")
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            HStack {
                Label("Notification access", systemImage: "bell")
                Spacer()
                Text(alertManager.notificationsAuthorized ? "Enabled" : "Disabled")
                    .font(.manasSubheadline)
                    .foregroundStyle(alertManager.notificationsAuthorized ? .green : .secondary)
            }
            if !alertManager.notificationsAuthorized {
                Button("Enable Notifications") {
                    Task { await alertManager.requestAuthorization() }
                }
                .foregroundStyle(.manasPrimary)
            }
        }
    }

    private var privacySection: some View {
        Section {
            Label("All data processed on-device", systemImage: "iphone.and.arrow.forward")
            Label("HealthKit data never transmitted raw", systemImage: "lock.shield.fill")
            Label("Keychain-encrypted contact storage", systemImage: "key.fill")
            Label("No advertising or analytics SDKs", systemImage: "hand.raised.fill")
        } header: {
            Text("Privacy")
        } footer: {
            Text("Manas is designed to comply with HIPAA and Apple's privacy guidelines. Only derived risk scores — never raw biometric values — are sent to the MAANAS backend when you opt in.")
        }
    }

    private var dataSection: some View {
        Section("Your Data") {
            Button {
                exportURL = exportData()
                if exportURL != nil { showExportSheet = true }
            } label: {
                Label("Export My Data", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.manasPrimary)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete All My Data", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            Link("Privacy Policy", destination: URL(string: "https://manas.health/privacy")!)
            Link("Terms of Service", destination: URL(string: "https://manas.health/terms")!)
        }
    }

    // MARK: - Actions

    private func deleteAllData() {
        SecureStorage.shared.deleteAll()
        contactStore.deleteAll()
        // Clear UserDefaults app state
        hasCompletedOnboarding = false
    }

    private func exportData() -> URL? {
        // Export a JSON summary of non-PHI data (no raw biometric readings).
        let export = DataExport(
            exportDate: Date(),
            contactCount: contactStore.contacts.count,
            note: "Raw biometric readings are processed on-device and are not stored by Manas."
        )
        guard let data = try? JSONEncoder().encode(export) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("manas-data-export.json")
        try? data.write(to: url)
        SecureStorage.applyFileProtection(to: url)
        return url
    }
}

// MARK: - Add contact sheet

private struct AddContactSheet: View {
    let onSave: (EmergencyContact) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var relationship = ""
    @State private var notifyAtHigh = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Info") {
                    TextField("Full name", text: $name)
                    TextField("Phone number", text: $phone).keyboardType(.phonePad)
                    TextField("Relationship (e.g. Parent, Friend)", text: $relationship)
                }
                Section {
                    Toggle("Also notify at High risk (not just Crisis)", isOn: $notifyAtHigh)
                } footer: {
                    Text("Crisis alerts are always sent regardless of this setting.")
                }
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(EmergencyContact(name: name, phoneNumber: phone,
                                               relationship: relationship, notifyAtHighRisk: notifyAtHigh))
                        dismiss()
                    }
                    .disabled(name.isEmpty || phone.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Share sheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Export payload (no PHI)

private struct DataExport: Encodable {
    let exportDate: Date
    let contactCount: Int
    let note: String
}
