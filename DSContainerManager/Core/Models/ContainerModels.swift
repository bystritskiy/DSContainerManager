import Foundation
import Tagged

// MARK: - Container (list response)

struct DockerContainer: Codable, Sendable, Equatable, Identifiable {
    let id: ContainerID
    let name: String
    let image: String
    let status: ContainerStatus
    let state: String
    let created: Date
    let ports: [PortMapping]
    let isPackage: Bool

    init(
        id: ContainerID,
        name: String,
        image: String,
        status: ContainerStatus,
        state: String,
        created: Date,
        ports: [PortMapping] = [],
        isPackage: Bool = false
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.state = state
        self.created = created
        self.ports = ports
        self.isPackage = isPackage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id can be "id" or "Id" or come as a string
        if let idStr = try? container.decode(String.self, forKey: .id) {
            id = ContainerID(rawValue: idStr)
        } else {
            id = ContainerID(rawValue: UUID().uuidString)
        }

        // name might have leading slash in Docker
        let rawName = (try? container.decode(String.self, forKey: .name)) ?? "unknown"
        name = rawName.hasPrefix("/") ? String(rawName.dropFirst()) : rawName

        image = (try? container.decode(String.self, forKey: .image)) ?? ""

        // status: try as ContainerStatus, fall back to string parsing
        if let s = try? container.decode(ContainerStatus.self, forKey: .status) {
            status = s
        } else if let statusStr = try? container.decode(String.self, forKey: .status) {
            status = ContainerStatus(rawValue: statusStr.lowercased()) ?? .unknown
        } else {
            status = .unknown
        }

        state = (try? container.decode(String.self, forKey: .state)) ?? ""

        // created: try as Date (seconds since 1970), or as Int, or as String
        if let ts = try? container.decode(Double.self, forKey: .created) {
            created = Date(timeIntervalSince1970: ts)
        } else if let ts = try? container.decode(Int.self, forKey: .created) {
            created = Date(timeIntervalSince1970: Double(ts))
        } else if let dateStr = try? container.decode(String.self, forKey: .created) {
            let formatter = ISO8601DateFormatter()
            created = formatter.date(from: dateStr) ?? .now
        } else {
            created = .now
        }

        ports = (try? container.decode([PortMapping].self, forKey: .ports)) ?? []
        isPackage = (try? container.decode(Bool.self, forKey: .isPackage)) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case image
        case status
        case state
        case created
        case ports
        case isPackage = "is_package"
    }

    struct PortMapping: Sendable, Equatable, Hashable, Codable {
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(privatePort, forKey: .privatePort)
            try container.encodeIfPresent(publicPort, forKey: .publicPort)
            try container.encode(type, forKey: .type)
        }

        let privatePort: Int
        let publicPort: Int?
        let type: String

        init(privatePort: Int, publicPort: Int? = nil, type: String = "tcp") {
            self.privatePort = privatePort
            self.publicPort = publicPort
            self.type = type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            privatePort = (try? container.decode(Int.self, forKey: .privatePort))
                ?? (try? container.decode(Int.self, forKey: .containerPort))
                ?? 0
            publicPort = (try? container.decode(Int.self, forKey: .publicPort))
                ?? (try? container.decode(Int.self, forKey: .hostPort))
            type = (try? container.decode(String.self, forKey: .type)) ?? "tcp"
        }

        enum CodingKeys: String, CodingKey {
            case privatePort = "private_port"
            case publicPort = "public_port"
            case containerPort = "container_port"
            case hostPort = "host_port"
            case type
        }

        var displayString: String {
            if let pub = publicPort {
                return "\(pub):\(privatePort)/\(type)"
            }
            return "\(privatePort)/\(type)"
        }
    }
}

// MARK: - Container Detail

struct ContainerDetail: Codable, Sendable, Equatable {
    let name: String
    let image: String
    let status: ContainerStatus
    let created: Date
    let env: [String]
    let cmd: [String]
    let volumes: [VolumeMount]
    let networks: [String]
    let labels: [String: String]
    let hostConfig: HostConfig?
    let ports: [DockerContainer.PortMapping]
    let restartPolicy: String?

    init(
        name: String, image: String, status: ContainerStatus, created: Date,
        env: [String] = [], cmd: [String] = [], volumes: [VolumeMount] = [],
        networks: [String] = [], labels: [String: String] = [:],
        hostConfig: HostConfig? = nil, ports: [DockerContainer.PortMapping] = [],
        restartPolicy: String? = nil
    ) {
        self.name = name
        self.image = image
        self.status = status
        self.created = created
        self.env = env
        self.cmd = cmd
        self.volumes = volumes
        self.networks = networks
        self.labels = labels
        self.hostConfig = hostConfig
        self.ports = ports
        self.restartPolicy = restartPolicy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        image = (try? container.decode(String.self, forKey: .image)) ?? ""
        status = (try? container.decode(ContainerStatus.self, forKey: .status)) ?? .unknown

        if let ts = try? container.decode(Double.self, forKey: .created) {
            created = Date(timeIntervalSince1970: ts)
        } else if let ts = try? container.decode(Int.self, forKey: .created) {
            created = Date(timeIntervalSince1970: Double(ts))
        } else {
            created = .now
        }

        env = (try? container.decode([String].self, forKey: .env)) ?? []
        cmd = (try? container.decode([String].self, forKey: .cmd)) ?? []
        volumes = (try? container.decode([VolumeMount].self, forKey: .volumes)) ?? []
        networks = (try? container.decode([String].self, forKey: .networks)) ?? []
        labels = (try? container.decode([String: String].self, forKey: .labels)) ?? [:]
        hostConfig = try? container.decode(HostConfig.self, forKey: .hostConfig)
        ports = (try? container.decode([DockerContainer.PortMapping].self, forKey: .ports)) ?? []
        restartPolicy = try? container.decode(String.self, forKey: .restartPolicy)
    }

    enum CodingKeys: String, CodingKey {
        case name, image, status, created, env, cmd, volumes, networks, labels, ports
        case hostConfig = "host_config"
        case restartPolicy = "restart_policy"
    }

    struct VolumeMount: Sendable, Equatable, Hashable, Identifiable, Codable {
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(source, forKey: .source)
            try container.encode(destination, forKey: .destination)
            try container.encode(mode, forKey: .mode)
        }

        nonisolated var id: String { "\(source):\(destination)" }
        let source: String
        let destination: String
        let mode: String

        init(source: String, destination: String, mode: String = "rw") {
            self.source = source
            self.destination = destination
            self.mode = mode
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            source = (try? container.decode(String.self, forKey: .source))
                ?? (try? container.decode(String.self, forKey: .hostVolumePath))
                ?? ""
            destination = (try? container.decode(String.self, forKey: .destination))
                ?? (try? container.decode(String.self, forKey: .mountPoint))
                ?? ""
            mode = (try? container.decode(String.self, forKey: .mode)) ?? "rw"
        }

        enum CodingKeys: String, CodingKey {
            case source
            case destination
            case mode
            case hostVolumePath = "host_volume_path"
            case mountPoint = "mount_point"
        }

        var displayString: String {
            "\(source) → \(destination) (\(mode))"
        }
    }

    struct HostConfig: Codable, Sendable, Equatable {
        let memoryLimit: Int64?
        let cpuShares: Int?
        let restartPolicy: String?
        let networkMode: String?

        enum CodingKeys: String, CodingKey {
            case memoryLimit = "memory_limit"
            case cpuShares = "cpu_shares"
            case restartPolicy = "restart_policy"
            case networkMode = "network_mode"
        }
    }
}

// MARK: - Container Log Entry

struct ContainerLog: Sendable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let stream: LogStream
    let text: String
    let offset: Int

    enum LogStream: String, Sendable, Codable {
        case stdout
        case stderr
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self).lowercased()
            self = LogStream(rawValue: rawValue) ?? .unknown
        }
    }
}

// MARK: - Container List API Response
// Synology API may return containers as:
// 1. { "containers": [ ... ] }  — array under "containers" key
// 2. { "id1": { ... }, "id2": { ... } } — dictionary keyed by container ID
// 3. [ ... ] — direct array (unlikely but handled)

struct ContainerListResponse: Decodable, Sendable {
    let containers: [DockerContainer]

    init(containers: [DockerContainer]) {
        self.containers = containers
    }

    init(from decoder: Decoder) throws {
        // Strategy 1: Object with "containers" array
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? keyed.decode([DockerContainer].self, forKey: .containers) {
            containers = arr
            return
        }

        // Strategy 2: Dictionary keyed by container ID (Synology Container Manager format)
        if let dict = try? decoder.singleValueContainer().decode([String: DockerContainer].self) {
            containers = Array(dict.values)
            return
        }

        // Strategy 3: Try as dictionary with flexible value decoding
        // Some Synology versions return data where values are container objects
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var result: [DockerContainer] = []
            for key in keyed.allKeys {
                // Skip known metadata keys
                if ["offset", "total", "limit"].contains(key.stringValue) { continue }
                if let container = try? keyed.decode(DockerContainer.self, forKey: key) {
                    result.append(container)
                }
            }
            if !result.isEmpty {
                containers = result
                return
            }
        }

        // Strategy 4: Direct array
        if let arr = try? decoder.singleValueContainer().decode([DockerContainer].self) {
            containers = arr
            return
        }

        // Fallback: empty
        #if DEBUG
        print("[ContainerListResponse] Could not decode containers from response")
        #endif
        containers = []
    }

    enum CodingKeys: String, CodingKey {
        case containers
    }
}

// Dynamic coding key for dictionary-style responses
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
