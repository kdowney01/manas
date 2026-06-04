import Foundation

struct EmergencyContact: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var phoneNumber: String       // E.164 format preferred
    var relationship: String
    var notifyAtHighRisk: Bool    // true = SMS at .high, always at .crisis
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        relationship: String,
        notifyAtHighRisk: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.notifyAtHighRisk = notifyAtHighRisk
        self.createdAt = createdAt
    }
}

// MARK: - Persistent store (Keychain-backed, never plain UserDefaults)

@MainActor
final class EmergencyContactStore: ObservableObject {
    @Published private(set) var contacts: [EmergencyContact] = []

    private let storage = SecureStorage.shared
    private let key = SecureStorage.Keys.emergencyContacts.rawValue

    init() { load() }

    func add(_ contact: EmergencyContact) {
        contacts.append(contact)
        persist()
    }

    func update(_ contact: EmergencyContact) {
        guard let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[idx] = contact
        persist()
    }

    func delete(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ contact: EmergencyContact) {
        contacts.removeAll { $0.id == contact.id }
        persist()
    }

    func deleteAll() {
        contacts = []
        storage.delete(key: key)
    }

    // MARK: - Private

    private func load() {
        contacts = (try? storage.loadCodable([EmergencyContact].self, key: key)) ?? []
    }

    private func persist() {
        try? storage.saveCodable(contacts, key: key)
    }
}
