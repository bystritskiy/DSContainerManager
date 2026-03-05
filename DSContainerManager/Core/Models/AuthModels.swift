import Foundation
import Tagged

// MARK: - Auth Session

struct AuthSession: Codable, Sendable, Equatable {
    let sid: SessionID
    let synotoken: String?
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case sid
        case synotoken
        case deviceId = "did"
    }
}

// MARK: - Login Response (raw API shape)

struct LoginResponseData: Decodable, Sendable {
    let sid: String
    let synotoken: String?
    let did: String?

    func toSession() -> AuthSession {
        AuthSession(
            sid: SessionID(rawValue: sid),
            synotoken: synotoken,
            deviceId: did
        )
    }
}
