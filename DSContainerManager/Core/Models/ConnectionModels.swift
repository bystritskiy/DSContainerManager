import Foundation
import SwiftData
import Tagged

// MARK: - NAS Connection (persisted via SwiftData)

@Model
final class NASConnection: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int
    var useHTTPS: Bool
    var username: String
    var use2FA: Bool
    var lastConnected: Date?
    var isDefault: Bool
    var trustSelfSignedCert: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 5000,
        useHTTPS: Bool = false,
        username: String,
        use2FA: Bool = false,
        lastConnected: Date? = nil,
        isDefault: Bool = false,
        trustSelfSignedCert: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useHTTPS = useHTTPS
        self.username = username
        self.use2FA = use2FA
        self.lastConnected = lastConnected
        self.isDefault = isDefault
        self.trustSelfSignedCert = trustSelfSignedCert
    }

    var baseURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")
    }

    var connectionID: ConnectionID {
        ConnectionID(rawValue: id)
    }
}

// MARK: - Sendable snapshot for use across actor boundaries

struct ConnectionProfile: Sendable, Equatable, Identifiable, Codable {
    let id: UUID
    let name: String
    let host: String
    let port: Int
    let useHTTPS: Bool
    let username: String
    let use2FA: Bool
    let lastConnected: Date?
    let isDefault: Bool
    let trustSelfSignedCert: Bool

    var baseURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")
    }

    var connectionID: ConnectionID {
        ConnectionID(rawValue: id)
    }
}

extension NASConnection {
    func toProfile() -> ConnectionProfile {
        ConnectionProfile(
            id: id,
            name: name,
            host: host,
            port: port,
            useHTTPS: useHTTPS,
            username: username,
            use2FA: use2FA,
            lastConnected: lastConnected,
            isDefault: isDefault,
            trustSelfSignedCert: trustSelfSignedCert
        )
    }
}
