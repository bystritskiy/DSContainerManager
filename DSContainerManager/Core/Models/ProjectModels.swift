import Foundation
import Tagged

// MARK: - Compose Project

struct ComposeProject: Codable, Equatable, Identifiable {
    let id: ProjectID
    let name: String
    let status: ProjectStatus
    let path: String
    let sharePath: String
    let containerIds: [String]
    let services: [ProjectService]
    let composeContent: String?
    let version: Int

    init(
        id: ProjectID,
        name: String,
        status: ProjectStatus,
        path: String = "",
        sharePath: String = "",
        containerIds: [String] = [],
        services: [ProjectService] = [],
        composeContent: String? = nil,
        version: Int = 0,
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.path = path
        self.sharePath = sharePath
        self.containerIds = containerIds
        self.services = services
        self.composeContent = composeContent
        self.version = version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let idStr = try? container.decode(String.self, forKey: .id) {
            id = ProjectID(rawValue: idStr)
        } else if let idStr = try? container.decode(String.self, forKey: .name) {
            id = ProjectID(rawValue: idStr)
        } else {
            id = ProjectID(rawValue: UUID().uuidString)
        }

        name = (try? container.decode(String.self, forKey: .name)) ?? ""

        if let decodedStatus = try? container.decode(ProjectStatus.self, forKey: .status) {
            status = decodedStatus
        } else if let statusStr = try? container.decode(String.self, forKey: .status) {
            status = ProjectStatus(rawValue: statusStr) ?? .unknown
        } else {
            status = .unknown
        }

        path = (try? container.decode(String.self, forKey: .path)) ?? ""
        sharePath = (try? container.decode(String.self, forKey: .sharePath)) ?? ""
        containerIds = (try? container.decode([String].self, forKey: .containerIds)) ?? []
        services = (try? container.decode([ProjectService].self, forKey: .services)) ?? []
        composeContent = try? container.decode(String.self, forKey: .composeContent)
        version = (try? container.decode(Int.self, forKey: .version)) ?? 0
    }

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

    var serviceCount: Int {
        services.count
    }

    var containerCount: Int {
        containerIds.count
    }
}

// MARK: - Project Service

struct ProjectService: Equatable, Identifiable, Hashable, Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(status, forKey: .status)
    }

    let id: String
    let displayName: String
    let image: String?
    let status: ContainerStatus?

    init(id: String, displayName: String, image: String? = nil, status: ContainerStatus? = nil) {
        self.id = id
        self.displayName = displayName
        self.image = image
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .serviceName))
            ?? UUID().uuidString
        displayName = (try? container.decode(String.self, forKey: .displayName))
            ?? (try? container.decode(String.self, forKey: .serviceName))
            ?? ""
        image = try? container.decode(String.self, forKey: .image)
        status = try? container.decode(ContainerStatus.self, forKey: .status)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case serviceName = "service_name"
        case image
        case status
    }
}

// MARK: - Project List API Response

// Synology API may return projects as:
// 1. { "projects": [ ... ] }  — array under "projects" key
// 2. { "uuid1": { ... }, "uuid2": { ... } } — dictionary keyed by project UUID
// 3. [ ... ] — direct array

struct ProjectListResponse: Decodable {
    let projects: [ComposeProject]

    init(projects: [ComposeProject]) {
        self.projects = projects
    }

    init(from decoder: Decoder) throws {
        // Strategy 1: Object with "projects" array
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? keyed.decode([ComposeProject].self, forKey: .projects)
        {
            projects = arr
            return
        }

        // Strategy 2: Dictionary keyed by project UUID (Synology Container Manager format)
        if let dict = try? decoder.singleValueContainer().decode([String: ComposeProject].self) {
            projects = Array(dict.values)
            return
        }

        // Strategy 3: Try as dictionary with flexible value decoding
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var result: [ComposeProject] = []
            for key in keyed.allKeys {
                if ["offset", "total", "limit"].contains(key.stringValue) { continue }
                if let project = try? keyed.decode(ComposeProject.self, forKey: key) {
                    result.append(project)
                }
            }
            if !result.isEmpty {
                projects = result
                return
            }
        }

        // Strategy 4: Direct array
        if let arr = try? decoder.singleValueContainer().decode([ComposeProject].self) {
            projects = arr
            return
        }

        // Fallback: empty
        #if DEBUG
            print("[ProjectListResponse] Could not decode projects from response")
        #endif
        projects = []
    }

    enum CodingKeys: String, CodingKey {
        case projects
    }
}
