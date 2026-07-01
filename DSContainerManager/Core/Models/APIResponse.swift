import Foundation

// MARK: - Generic Synology API Response

struct SynologyResponse<T: Decodable & Sendable>: Decodable {
    let success: Bool
    let data: T?
    let error: SynologyErrorPayload?
}

struct SynologyErrorPayload: Decodable {
    let code: Int
}

// MARK: - Empty response for actions that return no data

struct EmptyResponse: Decodable {}

// MARK: - API Info response

struct APIInfoResponse: Decodable {
    let entries: [String: APIEndpointInfo]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        entries = try container.decode([String: APIEndpointInfo].self)
    }
}

struct APIEndpointInfo: Decodable {
    let path: String
    let minVersion: Int
    let maxVersion: Int
}
