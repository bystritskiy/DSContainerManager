import Foundation
import Tagged

enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo-mode")
            || ProcessInfo.processInfo.environment["DSCM_DEMO_MODE"] == "1"
    }

    static let connectionId = UUID(uuidString: "D5C0DE00-0000-4000-9000-000000000001")!

    static let connectionProfile = ConnectionProfile(
        id: connectionId,
        name: "Demo NAS",
        host: "demo-nas.local",
        port: 5001,
        useHTTPS: true,
        username: "demo",
        lastConnected: Date(timeIntervalSince1970: 1_782_916_800),
        isDefault: true,
        trustSelfSignedCert: true,
    )

    static let authSession = AuthSession(
        sid: SessionID(rawValue: "demo-session"),
        synotoken: "demo-token",
        deviceId: "demo-device",
    )
}

extension ConnectionStore {
    static let demoValue = ConnectionStore(
        fetchAll: {
            [DemoMode.connectionProfile]
        },
        save: { _ in },
        delete: { _ in },
        setDefault: { _ in },
    )
}

extension KeychainClient {
    static let demoValue = KeychainClient(
        save: { _, _ in },
        load: { key in
            if key == "active-session" {
                let saved = KeychainClient.SavedSession(
                    connectionId: DemoMode.connectionId,
                    session: DemoMode.authSession,
                )
                return try JSONEncoder().encode(saved)
            }

            if key == "connection-password-\(DemoMode.connectionId.uuidString)" {
                return "demo".data(using: .utf8)
            }

            return nil
        },
        delete: { _ in },
    )
}
