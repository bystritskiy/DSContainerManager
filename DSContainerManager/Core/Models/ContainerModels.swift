import Foundation
import Tagged

// MARK: - Container (list response)

struct DockerContainer: Codable, Equatable, Identifiable {
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
        isPackage: Bool = false,
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(image, forKey: .image)
        try container.encode(status, forKey: .status)
        try container.encode(state, forKey: .state)
        try container.encode(created, forKey: .created)
        try container.encode(ports, forKey: .ports)
        try container.encode(isPackage, forKey: .isPackage)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawID = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .idUpper))
            ?? UUID().uuidString
        id = ContainerID(rawValue: rawID)

        let rawName = (try? container.decode(String.self, forKey: .name))
            ?? (try? container.decode(String.self, forKey: .nameUpper))
            ?? (try? container.decode([String].self, forKey: .namesUpper).first)
            ?? "unknown"
        name = Self.normalizedContainerName(rawName)

        image = (try? container.decode(String.self, forKey: .image))
            ?? (try? container.decode(String.self, forKey: .imageUpper))
            ?? ""

        let rawStatus = (try? container.decode(String.self, forKey: .status))
            ?? (try? container.decode(String.self, forKey: .statusUpper))
            ?? (try? container.decode(RawState.self, forKey: .stateUpper).status)
            ?? (try? container.decode(String.self, forKey: .state))
            ?? ""
        status = Self.containerStatus(from: rawStatus)

        state = (try? container.decode(String.self, forKey: .state))
            ?? (try? container.decode(String.self, forKey: .stateUpper))
            ?? (try? container.decode(RawState.self, forKey: .stateUpper).status)
            ?? rawStatus

        if let ts = try? container.decode(Double.self, forKey: .created) {
            created = Date(timeIntervalSince1970: ts)
        } else if let ts = try? container.decode(Double.self, forKey: .createdUpper) {
            created = Date(timeIntervalSince1970: ts)
        } else if let ts = try? container.decode(Int.self, forKey: .created) {
            created = Date(timeIntervalSince1970: Double(ts))
        } else if let ts = try? container.decode(Int.self, forKey: .createdUpper) {
            created = Date(timeIntervalSince1970: Double(ts))
        } else if let dateStr = (try? container.decode(String.self, forKey: .created))
            ?? (try? container.decode(String.self, forKey: .createdUpper))
        {
            let formatter = ISO8601DateFormatter()
            created = formatter.date(from: dateStr) ?? .now
        } else {
            created = .now
        }

        ports = (try? container.decode([PortMapping].self, forKey: .ports))
            ?? (try? container.decode([PortMapping].self, forKey: .portsUpper))
            ?? []
        isPackage = (try? container.decode(Bool.self, forKey: .isPackage))
            ?? (try? container.decode(Bool.self, forKey: .isPackageUpper))
            ?? false
    }

    fileprivate static func normalizedContainerName(_ rawName: String) -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix("/") {
            name.removeFirst()
        }
        return name.isEmpty ? "unknown" : name
    }

    fileprivate static func containerStatus(from rawStatus: String) -> ContainerStatus {
        let lowercasedStatus = rawStatus.lowercased()
        if lowercasedStatus.hasPrefix("up") || lowercasedStatus == "running" {
            return .running
        }
        if lowercasedStatus.contains("pause") {
            return .paused
        }
        if lowercasedStatus.contains("restart") {
            return .restarting
        }
        if lowercasedStatus.contains("dead") {
            return .dead
        }
        if lowercasedStatus.contains("created") {
            return .created
        }
        if lowercasedStatus.contains("exit") || lowercasedStatus == "stopped" {
            return .stopped
        }
        return ContainerStatus(rawValue: lowercasedStatus) ?? .unknown
    }

    private struct RawState: Decodable {
        let status: String?

        enum CodingKeys: String, CodingKey {
            case status = "Status"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case idUpper = "Id"
        case name
        case nameUpper = "Name"
        case namesUpper = "Names"
        case image
        case imageUpper = "Image"
        case status
        case statusUpper = "Status"
        case state
        case stateUpper = "State"
        case created
        case createdUpper = "Created"
        case ports
        case portsUpper = "Ports"
        case isPackage = "is_package"
        case isPackageUpper = "isPackage"
    }

    struct PortMapping: Equatable, Hashable, Codable {
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

struct ContainerDetail: Codable, Equatable {
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
        restartPolicy: String? = nil,
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(image, forKey: .image)
        try container.encode(status, forKey: .status)
        try container.encode(created, forKey: .created)
        try container.encode(env, forKey: .env)
        try container.encode(cmd, forKey: .cmd)
        try container.encode(volumes, forKey: .volumes)
        try container.encode(networks, forKey: .networks)
        try container.encode(labels, forKey: .labels)
        try container.encodeIfPresent(hostConfig, forKey: .hostConfig)
        try container.encode(ports, forKey: .ports)
        try container.encodeIfPresent(restartPolicy, forKey: .restartPolicy)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.details), let nestedDecoder = try? container.superDecoder(forKey: .details) {
            self = try Self(from: nestedDecoder)
            return
        }

        let config = try? container.decode(RawConfig.self, forKey: .config)
        let rawState = try? container.decode(RawState.self, forKey: .stateUpper)

        let rawName = (try? container.decode(String.self, forKey: .name))
            ?? (try? container.decode(String.self, forKey: .nameUpper))
            ?? ""
        let decodedName = DockerContainer.normalizedContainerName(rawName)

        let decodedImage = (try? container.decode(String.self, forKey: .image))
            ?? (try? container.decode(String.self, forKey: .imageUpper))
            ?? config?.image
            ?? ""

        let rawStatus = (try? container.decode(String.self, forKey: .status))
            ?? (try? container.decode(String.self, forKey: .statusUpper))
            ?? rawState?.status
            ?? ""
        let decodedStatus = DockerContainer.containerStatus(from: rawStatus)

        let decodedCreated: Date
        if let ts = try? container.decode(Double.self, forKey: .created) {
            decodedCreated = Date(timeIntervalSince1970: ts)
        } else if let ts = try? container.decode(Int.self, forKey: .created) {
            decodedCreated = Date(timeIntervalSince1970: Double(ts))
        } else if let dateStr = (try? container.decode(String.self, forKey: .created))
            ?? (try? container.decode(String.self, forKey: .createdUpper))
        {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decodedCreated = formatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr) ?? .now
        } else {
            decodedCreated = .now
        }

        let decodedHostConfig = try? container.decode(HostConfig.self, forKey: .hostConfig)
        self.init(
            name: decodedName,
            image: decodedImage,
            status: decodedStatus,
            created: decodedCreated,
            env: (try? container.decode([String].self, forKey: .env)) ?? config?.env ?? [],
            cmd: (try? container.decode([String].self, forKey: .cmd)) ?? config?.cmd ?? config?.entrypoint ?? [],
            volumes: (try? container.decode([VolumeMount].self, forKey: .volumes))
                ?? (try? container.decode([VolumeMount].self, forKey: .mounts))
                ?? [],
            networks: (try? container.decode([String].self, forKey: .networks)) ?? [],
            labels: (try? container.decode([String: String].self, forKey: .labels)) ?? config?.labels ?? [:],
            hostConfig: decodedHostConfig,
            ports: (try? container.decode([DockerContainer.PortMapping].self, forKey: .ports)) ?? [],
            restartPolicy: (try? container.decode(String.self, forKey: .restartPolicy)) ?? decodedHostConfig?.restartPolicy,
        )
    }

    private struct RawConfig: Decodable {
        let image: String?
        let env: [String]?
        let cmd: [String]?
        let entrypoint: [String]?
        let labels: [String: String]?

        enum CodingKeys: String, CodingKey {
            case image = "Image"
            case env = "Env"
            case cmd = "Cmd"
            case entrypoint = "Entrypoint"
            case labels = "Labels"
        }
    }

    private struct RawState: Decodable {
        let status: String?

        enum CodingKeys: String, CodingKey {
            case status = "Status"
        }
    }

    enum CodingKeys: String, CodingKey {
        case details
        case name
        case nameUpper = "Name"
        case image
        case imageUpper = "Image"
        case status
        case statusUpper = "Status"
        case stateUpper = "State"
        case created
        case createdUpper = "Created"
        case env, cmd, volumes, networks, labels, ports
        case config = "Config"
        case mounts = "Mounts"
        case hostConfig = "host_config"
        case restartPolicy = "restart_policy"
    }

    struct VolumeMount: Equatable, Hashable, Identifiable, Codable {
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(source, forKey: .source)
            try container.encode(destination, forKey: .destination)
            try container.encode(mode, forKey: .mode)
        }

        nonisolated var id: String {
            "\(source):\(destination)"
        }

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

    struct HostConfig: Codable, Equatable {
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

struct ContainerLog: Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let stream: LogStream
    let text: String
    let offset: Int

    enum LogStream: String, Codable {
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

struct ContainerListResponse: Decodable {
    let containers: [DockerContainer]

    init(containers: [DockerContainer]) {
        self.containers = containers
    }

    init(from decoder: Decoder) throws {
        // Strategy 1: Object with "containers" array
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? keyed.decode([DockerContainer].self, forKey: .containers)
        {
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

/// Dynamic coding key for dictionary-style responses
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
