import Foundation
import Dependencies
import DependenciesMacros
import SwiftData

// MARK: - Connection Store Interface

@DependencyClient
struct ConnectionStore: Sendable {
    var fetchAll: @Sendable () async throws -> [ConnectionProfile]
    var save: @Sendable (_ profile: ConnectionProfile) async throws -> Void
    var delete: @Sendable (_ id: UUID) async throws -> Void
    var setDefault: @Sendable (_ id: UUID) async throws -> Void
}

// MARK: - Live Implementation

extension ConnectionStore: DependencyKey {
    static let liveValue: ConnectionStore = {
        let container: ModelContainer = {
            let schema = Schema([NASConnection.self])
            let config = ModelConfiguration("DSContainerManager", isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }()

        return ConnectionStore(
            fetchAll: {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<NASConnection>(
                    sortBy: [SortDescriptor(\.name)]
                )
                let connections = try context.fetch(descriptor)
                return connections.map { $0.toProfile() }
            },
            save: { profile in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<NASConnection>(
                    predicate: #Predicate { $0.id == profile.id }
                )
                let existing = try context.fetch(descriptor)

                if let connection = existing.first {
                    connection.name = profile.name
                    connection.host = profile.host
                    connection.port = profile.port
                    connection.useHTTPS = profile.useHTTPS
                    connection.username = profile.username
                    connection.use2FA = profile.use2FA
                    connection.isDefault = profile.isDefault
                    connection.trustSelfSignedCert = profile.trustSelfSignedCert
                } else {
                    let connection = NASConnection(
                        id: profile.id,
                        name: profile.name,
                        host: profile.host,
                        port: profile.port,
                        useHTTPS: profile.useHTTPS,
                        username: profile.username,
                        use2FA: profile.use2FA,
                        lastConnected: profile.lastConnected,
                        isDefault: profile.isDefault,
                        trustSelfSignedCert: profile.trustSelfSignedCert
                    )
                    context.insert(connection)
                }
                try context.save()
            },
            delete: { id in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<NASConnection>(
                    predicate: #Predicate { $0.id == id }
                )
                let connections = try context.fetch(descriptor)
                for connection in connections {
                    context.delete(connection)
                }
                try context.save()
            },
            setDefault: { id in
                let context = ModelContext(container)
                let allDescriptor = FetchDescriptor<NASConnection>()
                let all = try context.fetch(allDescriptor)
                for connection in all {
                    connection.isDefault = (connection.id == id)
                }
                try context.save()
            }
        )
    }()

    static let previewValue = ConnectionStore(
        fetchAll: {
            [
                ConnectionProfile(
                    id: UUID(),
                    name: "Home NAS",
                    host: "192.168.1.100",
                    port: 5000,
                    useHTTPS: false,
                    username: "admin",
                    use2FA: false,
                    lastConnected: Date.now.addingTimeInterval(-3600),
                    isDefault: true,
                    trustSelfSignedCert: false
                ),
                ConnectionProfile(
                    id: UUID(),
                    name: "Office NAS",
                    host: "nas.office.local",
                    port: 5001,
                    useHTTPS: true,
                    username: "admin",
                    use2FA: true,
                    lastConnected: Date.now.addingTimeInterval(-86400),
                    isDefault: false,
                    trustSelfSignedCert: true
                ),
            ]
        },
        save: { _ in },
        delete: { _ in },
        setDefault: { _ in }
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    var connectionStore: ConnectionStore {
        get { self[ConnectionStore.self] }
        set { self[ConnectionStore.self] = newValue }
    }
}
