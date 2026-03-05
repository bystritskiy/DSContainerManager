import Foundation

// MARK: - Generic Synology API Response

struct SynologyResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool
    let data: T?
    let error: SynologyErrorPayload?
}

struct SynologyErrorPayload: Decodable, Sendable {
    let code: Int
}

// MARK: - Empty response for actions that return no data

struct EmptyResponse: Decodable, Sendable {}

// MARK: - API Info response

struct APIInfoResponse: Decodable, Sendable {
    let entries: [String: APIEndpointInfo]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        entries = try container.decode([String: APIEndpointInfo].self)
    }
}

struct APIEndpointInfo: Decodable, Sendable {
    let path: String
    let minVersion: Int
    let maxVersion: Int
}
