import Foundation
import Tagged

// MARK: - Compose Project

struct ComposeProject: Codable, Sendable, Equatable, Identifiable {
    let id: ProjectID
    let name: String
    let status: ProjectStatus
    let path: String
    let sharePath: String
    let containerIds: [String]
    let services: [ProjectService]
    let composeContent: String?
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case path
        case sharePath = "share_path"
        case containerIds = "container_ids"
        case services
        case composeContent = "compose_content"
        case version
    }

    var serviceCount: Int { services.count }
    var containerCount: Int { containerIds.count }
}

// MARK: - Project Service

struct ProjectService: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let image: String?
    let status: ContainerStatus?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case image
        case status
    }
}

// MARK: - Project List API Response

struct ProjectListResponse: Decodable, Sendable {
    let projects: [ComposeProject]
}
