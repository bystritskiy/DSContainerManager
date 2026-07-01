import Dependencies
import DependenciesMacros
import Foundation
import Security

// MARK: - Keychain Client Interface

@DependencyClient
struct KeychainClient {
    var save: @Sendable (_ data: Data, _ key: String) throws -> Void
    var load: @Sendable (_ key: String) throws -> Data?
    var delete: @Sendable (_ key: String) throws -> Void
}

// MARK: - Keychain Errors

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case let .saveFailed(status):
            "Failed to save to Keychain (status: \(status))"
        case let .loadFailed(status):
            "Failed to load from Keychain (status: \(status))"
        case let .deleteFailed(status):
            "Failed to delete from Keychain (status: \(status))"
        case .unexpectedData:
            "Unexpected data format in Keychain"
        }
    }
}

// MARK: - Live Implementation

extension KeychainClient: DependencyKey {
    static let liveValue = KeychainClient(
        save: { data, key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.dscontainermanager",
                kSecValueData as String: data,
            ]

            // Delete existing item first
            SecItemDelete(query as CFDictionary)

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.saveFailed(status)
            }
        },
        load: { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.dscontainermanager",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecItemNotFound {
                return nil
            }

            guard status == errSecSuccess else {
                throw KeychainError.loadFailed(status)
            }

            return result as? Data
        },
        delete: { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.dscontainermanager",
            ]

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deleteFailed(status)
            }
        }
    )

    static let previewValue = KeychainClient(
        save: { _, _ in },
        load: { _ in nil },
        delete: { _ in }
    )
}

extension KeychainClient: TestDependencyKey {
    static let testValue = previewValue
}

// MARK: - Dependency Registration

extension DependencyValues {
    var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}

// MARK: - Convenience Methods

extension KeychainClient {
    func savePassword(_ password: String, forConnection id: UUID) throws {
        guard let data = password.data(using: .utf8) else { return }
        try save(data, "connection-password-\(id.uuidString)")
    }

    func loadPassword(forConnection id: UUID) throws -> String? {
        guard let data = try load("connection-password-\(id.uuidString)") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deletePassword(forConnection id: UUID) throws {
        try delete("connection-password-\(id.uuidString)")
    }
}

// MARK: - Session Persistence

/// Stores the active session so the user doesn't have to re-enter 2FA on every app launch.
/// The session is saved per-connection using the connection UUID as part of the key.
extension KeychainClient {
    private static let sessionKey = "active-session"
    private static let sessionConnectionKey = "active-session-connection-id"

    /// Persisted session data: AuthSession + the connection UUID it belongs to
    struct SavedSession: Codable {
        let connectionId: UUID
        let session: AuthSession
    }

    func saveSession(_ session: AuthSession, forConnection id: UUID) throws {
        let saved = SavedSession(connectionId: id, session: session)
        let data = try JSONEncoder().encode(saved)
        try save(data, Self.sessionKey)
    }

    func loadSavedSession() throws -> SavedSession? {
        guard let data = try load(Self.sessionKey) else { return nil }
        return try? JSONDecoder().decode(SavedSession.self, from: data)
    }

    func deleteSavedSession() throws {
        try delete(Self.sessionKey)
    }
}
