import SwiftUI

struct CompanionView: View {
    @StateObject private var service = CompanionService()
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var riskEngine: RiskScoringEngine
    @State private var inputText = ""
    @State private var showPersonaPicker = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                personaBar
                Divider()
                messageList
                inputBar
            }
            .background(Color.manasBackground.ignoresSafeArea())
            .navigationTitle(service.selectedPersona.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New") {
                        service.startSession(
                            riskEvent: riskEngine.recentEvents.first,
                            snapshot: healthKitManager.latestSnapshot
                        )
                    }
                    .font(.manasSubheadline)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPersonaPicker = true
                    } label: {
                        Label("Switch", systemImage: "person.2.fill")
                            .font(.manasSubheadline)
                    }
                }
            }
            .sheet(isPresented: $showPersonaPicker) {
                PersonaPickerSheet(selectedPersona: $service.selectedPersona) {
                    service.startSession(
                        riskEvent: riskEngine.recentEvents.first,
                        snapshot: healthKitManager.latestSnapshot
                    )
                }
            }
            .task {
                if service.messages.isEmpty {
                    service.startSession(
                        riskEvent: riskEngine.recentEvents.first,
                        snapshot: healthKitManager.latestSnapshot
                    )
                }
            }
        }
    }

    // MARK: - Persona bar

    private var personaBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DoctorPersona.allCases) { persona in
                    Button {
                        service.selectedPersona = persona
                        service.startSession(
                            riskEvent: riskEngine.recentEvents.first,
                            snapshot: healthKitManager.latestSnapshot
                        )
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: persona.systemIconName)
                                .font(.system(size: 11, weight: .medium))
                            Text(persona.displayName)
                                .font(.manasCaption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            service.selectedPersona == persona
                                ? Color.manasPrimary
                                : Color(.secondarySystemBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            service.selectedPersona == persona ? .white : Color.secondary
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(service.messages) { message in
                        MessageBubble(message: message, persona: service.selectedPersona)
                            .id(message.id)
                    }
                    if service.isLoading {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: service.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(service.isLoading ? "typing" : service.messages.last?.id) }
            }
            .onChange(of: service.isLoading) { _, loading in
                if loading { withAnimation { proxy.scrollTo("typing") } }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Message \(service.selectedPersona.displayName)…", text: $inputText, axis: .vertical)
                    .font(.manasBody)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    inputText = ""
                    Task { await service.send(text, snapshot: healthKitManager.latestSnapshot) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.manasPrimary)
                }
                .disabled(inputText.isEmpty || service.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let persona: DoctorPersona

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                Image(systemName: persona.systemIconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.manasPrimary, in: Circle())
            }

            Text(message.content)
                .font(.manasSubheadline)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Color.manasPrimary : Color(.systemBackground),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: .black.opacity(isUser ? 0 : 0.05), radius: 4, x: 0, y: 1)

            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(Color.manasPrimary)
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "ellipsis").font(.system(size: 10, weight: .bold)).foregroundStyle(.white))
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            Spacer()
        }
        .onAppear { phase = 1 }
    }
}

// MARK: - Persona picker sheet

private struct PersonaPickerSheet: View {
    @Binding var selectedPersona: DoctorPersona
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(DoctorPersona.allCases) { persona in
                Button {
                    selectedPersona = persona
                    onSelect()
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: persona.systemIconName)
                            .font(.title3)
                            .foregroundStyle(.manasPrimary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(persona.displayName).font(.manasHeadline).foregroundStyle(.primary)
                            Text(persona.description).font(.manasCaption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if persona == selectedPersona {
                            Image(systemName: "checkmark").foregroundStyle(.manasPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Choose Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
