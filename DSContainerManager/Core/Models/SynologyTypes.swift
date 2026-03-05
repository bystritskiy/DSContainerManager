import Foundation
import Tagged

// MARK: - Tagged ID Types

enum ContainerIDTag {}
typealias ContainerID = Tagged<ContainerIDTag, String>

enum ProjectIDTag {}
typealias ProjectID = Tagged<ProjectIDTag, String>

enum SessionIDTag {}
typealias SessionID = Tagged<SessionIDTag, String>

enum ConnectionIDTag {}
typealias ConnectionID = Tagged<ConnectionIDTag, UUID>

// MARK: - Container Status

enum ContainerStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case running
    case stopped
    case paused
    case restarting
    case created
    case dead
    case unknown

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .paused: "Paused"
        case .restarting: "Restarting"
        case .created: "Created"
        case .dead: "Dead"
        case .unknown: "Unknown"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        self = ContainerStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Project Status

enum ProjectStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case running = "RUNNING"
    case stopped = "STOPPED"
    case partiallyRunning = "PARTIALLY_RUNNING"
    case unknown

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .partiallyRunning: "Partial"
        case .unknown: "Unknown"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ProjectStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Container Action

enum ContainerAction: String, Sendable {
    case start
    case stop
    case restart
    case pause
    case unpause
    case kill
}

// MARK: - Project Action

enum ProjectAction: String, Sendable {
    case start
    case stop
    case restart
}
