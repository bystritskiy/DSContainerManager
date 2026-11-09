import Foundation

// MARK: - Typed IDs

/// A raw value distinguished at compile time by a phantom `Tag`, so a `ProjectID`
/// can't be passed where a `ContainerID` is expected even though both wrap `String`.
///
/// Encodes and decodes as the bare raw value (no wrapping object), matching the
/// on-disk format of previously persisted sessions.
struct TypedID<Tag, RawValue>: RawRepresentable {
    var rawValue: RawValue
}

extension TypedID: Equatable where RawValue: Equatable {}
extension TypedID: Hashable where RawValue: Hashable {}
extension TypedID: Sendable where RawValue: Sendable {}

extension TypedID: Decodable where RawValue: Decodable {
    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(RawValue.self)
    }
}

extension TypedID: Encodable where RawValue: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension TypedID: CustomStringConvertible {
    var description: String {
        String(describing: rawValue)
    }
}

enum ContainerIDTag {}
typealias ContainerID = TypedID<ContainerIDTag, String>

enum ProjectIDTag {}
typealias ProjectID = TypedID<ProjectIDTag, String>

enum SessionIDTag {}
typealias SessionID = TypedID<SessionIDTag, String>

enum ConnectionIDTag {}
typealias ConnectionID = TypedID<ConnectionIDTag, UUID>

// MARK: - Container Status

enum ContainerStatus: String, Codable, CaseIterable, Identifiable {
    case running
    case stopped
    case paused
    case restarting
    case created
    case dead
    case unknown

    nonisolated var id: String {
        rawValue
    }

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

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case running = "RUNNING"
    case stopped = "STOPPED"
    case partiallyRunning = "PARTIALLY_RUNNING"
    case unknown

    nonisolated var id: String {
        rawValue
    }

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

enum ContainerAction: String {
    case start
    case stop
    case restart
    case pause
    case unpause
    case kill
}

// MARK: - Project Action

enum ProjectAction: String {
    case start
    case stop
    case restart
}
