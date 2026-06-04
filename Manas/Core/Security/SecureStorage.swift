import Foundation
import Security
import CryptoKit
import OSLog

// HIPAA note: this class handles all sensitive credential and config storage.
// Raw PHI (biometric readings) must never be stored here — only derived scores,
// tokens, and user-controlled configuration (emergency contacts, profile prefs).

private let log = Logger(subsystem: "com.manas.app", category: "SecureStorage")

final class SecureStorage {
    static let shared = SecureStorage()
    private init() {}

    // MARK: - Keychain read / write

    func save(_ data: Data, key: String) throws {
        let attrs: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String:        data
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status != errSecSuccess {
            log.error("Keychain write failed for key \(key, privacy: .public): \(status)")
            throw SecureStorageError.writeFailed(status)
        }
    }

    func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw SecureStorageError.readFailed(status)
        }
        return data
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        for key in Keys.allCases { delete(key: key.rawValue) }
        log.info("All Manas Keychain entries deleted (user request)")
    }

    // MARK: - Typed convenience

    func saveString(_ s: String, key: String) throws {
        guard let d = s.data(using: .utf8) else { throw SecureStorageError.encodingFailed }
        try save(d, key: key)
    }

    func loadString(key: String) throws -> String {
        let d = try load(key: key)
        guard let s = String(data: d, encoding: .utf8) else { throw SecureStorageError.decodingFailed }
        return s
    }

    func saveCodable<T: Encodable>(_ value: T, key: String) throws {
        let d = try JSONEncoder().encode(value)
        try save(d, key: key)
    }

    func loadCodable<T: Decodable>(_ type: T.Type, key: String) throws -> T {
        let d = try load(key: key)
        return try JSONDecoder().decode(type, from: d)
    }

    // MARK: - App-level data encryption key
    // Used to encrypt any sensitive data written to disk outside the Keychain.

    func appEncryptionKey() throws -> SymmetricKey {
        if let d = try? load(key: Keys.dataEncryptionKey.rawValue) {
            return SymmetricKey(data: d)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try save(keyData, key: Keys.dataEncryptionKey.rawValue)
        log.info("Generated new app-level AES-256 data encryption key")
        return key
    }

    // MARK: - File protection helper
    // Call on any file URL before writing sensitive data to disk.

    static func applyFileProtection(to url: URL) {
        try? (url as NSURL).setResourceValue(
            URLFileProtection.completeUnlessOpen,
            forKey: .fileProtectionKey
        )
    }
}

// MARK: - Keys

extension SecureStorage {
    enum Keys: String, CaseIterable {
        case dataEncryptionKey  = "com.manas.sec.dek"
        case jwtToken           = "com.manas.auth.jwt"
        case userID             = "com.manas.auth.uid"
        case userProfile        = "com.manas.user.profile"
        case emergencyContacts  = "com.manas.user.emergency-contacts"
        case consentRecord      = "com.manas.user.consent"
    }
}

// MARK: - Errors

enum SecureStorageError: LocalizedError {
    case writeFailed(OSStatus)
    case readFailed(OSStatus)
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed(let s):  return "Keychain write failed (\(s))"
        case .readFailed(let s):   return "Keychain read failed (\(s))"
        case .encodingFailed:      return "Failed to encode value for Keychain"
        case .decodingFailed:      return "Failed to decode value from Keychain"
        }
    }
}
