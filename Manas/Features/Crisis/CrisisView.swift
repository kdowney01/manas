import SwiftUI
import MessageUI

struct CrisisView: View {
    let event: RiskEvent
    @EnvironmentObject var contactStore: EmergencyContactStore
    @EnvironmentObject var alertManager: AlertManager
    @State private var showingSMSComposer = false
    @State private var smsRecipients: [String] = []
    @State private var contactsNotified = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                crisisLineCard
                if !contactStore.contacts.isEmpty {
                    emergencyContactsCard
                }
                companionCard
                dismissButton
            }
            .padding(20)
        }
        .background(Color.manasBackground.ignoresSafeArea())
        .navigationTitle("Support Available")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSMSComposer) {
            SMSComposerView(recipients: smsRecipients, body: smsBody)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text("You're not alone")
                .font(.manasTitle2)
                .foregroundStyle(.primary)
            Text("Manas detected signals that may indicate you need support right now. Help is available immediately.")
                .font(.manasSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var crisisLineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Crisis Lifeline", systemImage: "phone.fill")
                .font(.manasHeadline)
                .foregroundStyle(.manasPrimary)

            Text("Free, confidential support 24/7. Call or text 988 to reach the Suicide & Crisis Lifeline.")
                .font(.manasSubheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                crisisActionButton(
                    title: "Call 988",
                    icon: "phone.fill",
                    color: .red
                ) {
                    guard let url = URL(string: "tel://988") else { return }
                    UIApplication.shared.open(url)
                }
                crisisActionButton(
                    title: "Text 988",
                    icon: "message.fill",
                    color: .manasPrimary
                ) {
                    smsRecipients = ["988"]
                    showingSMSComposer = true
                }
            }

            Link("Chat at 988lifeline.org →", destination: URL(string: "https://988lifeline.org/chat/")!)
                .font(.manasFootnote)
                .foregroundStyle(.manasPrimary)
        }
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var emergencyContactsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Alert Your Contacts", systemImage: "person.2.fill")
                .font(.manasHeadline)
                .foregroundStyle(.manasPrimary)

            if contactsNotified {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Message sent to your emergency contacts.")
                        .font(.manasSubheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(contactStore.contacts) { contact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).font(.manasSubheadline).fontWeight(.semibold)
                            Text(contact.relationship).font(.manasCaption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            smsRecipients = [contact.phoneNumber]
                            showingSMSComposer = true
                        } label: {
                            Label("Text", systemImage: "message")
                                .font(.manasCaption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(.manasPrimary, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    let allNumbers = contactStore.contacts.map(\.phoneNumber)
                    smsRecipients = allNumbers
                    showingSMSComposer = true
                } label: {
                    Label("Alert All Contacts", systemImage: "exclamationmark.bubble.fill")
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(.red, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .font(.manasSubheadline.bold())
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var companionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Talk to Your AI Companion", systemImage: "bubble.left.fill")
                .font(.manasHeadline)
                .foregroundStyle(.manasPrimary)
            Text("Your companion is ready to listen and guide you through grounding techniques.")
                .font(.manasSubheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var dismissButton: some View {
        Button("I'm safe — dismiss") {
            alertManager.clearCrisis()
        }
        .font(.manasSubheadline)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func crisisActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(13)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .font(.manasSubheadline.bold())
        }
    }

    private var smsBody: String {
        "Hi, I wanted you to know I may be struggling right now. Manas, my mental health app, flagged some concerning signals. I may need support."
    }
}

// MARK: - SMS Composer wrapper

struct SMSComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }

    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }
}
