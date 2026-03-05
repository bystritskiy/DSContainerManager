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

    struct PortMapping: Codable, Sendable, Equatable, Hashable {
        let privatePort: Int
        let publicPort: Int?
        let type: String

        enum CodingKeys: String, CodingKey {
            case privatePort = "private_port"
            case publicPort = "public_port"
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

    struct VolumeMount: Codable, Sendable, Equatable, Hashable, Identifiable {
        nonisolated var id: String { "\(source):\(destination)" }
        let source: String
        let destination: String
        let mode: String

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

struct ContainerListResponse: Decodable, Sendable {
    let containers: [DockerContainer]
}
