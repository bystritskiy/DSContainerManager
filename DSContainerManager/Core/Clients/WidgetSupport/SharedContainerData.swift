import Foundation
import Tagged

// MARK: - Shared Data for Widget Extension

/// Data model shared between the main app and widget extension via App Groups.
/// The main app writes this data; widgets read it.
struct SharedContainerData: Codable, Sendable {
    let timestamp: Date
    let containers: [SharedContainerInfo]
    let cpuPercent: Double
    let memoryPercent: Double
    let runningCount: Int
    let stoppedCount: Int
    let totalCount: Int
}

struct SharedContainerInfo: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let image: String
    let status: String
    let statusColor: String // hex color for display
}

// MARK: - App Group Storage

enum SharedStorage {
    static let appGroupIdentifier = "group.com.dscontainermanager.shared"
    static let containerDataKey = "containerData"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func saveContainerData(_ data: SharedContainerData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: containerDataKey)
        }
    }

    static func loadContainerData() -> SharedContainerData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: containerDataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedContainerData.self, from: data)
    }

    /// Called from the main app after fetching fresh data
    static func updateFromContainers(
        _ containers: [DockerContainer],
        cpuPercent: Double,
        memoryPercent: Double
    ) {
        let sharedContainers = containers.map { container in
            SharedContainerInfo(
                id: container.id.rawValue,
                name: container.name,
                image: container.image,
                status: container.status.rawValue,
                statusColor: container.status.hexColor
            )
        }

        let data = SharedContainerData(
            timestamp: .now,
            containers: sharedContainers,
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            runningCount: containers.filter { $0.status == .running }.count,
            stoppedCount: containers.filter { $0.status == .stopped }.count,
            totalCount: containers.count
        )

        saveContainerData(data)
    }
}

// MARK: - Status Color Hex

extension ContainerStatus {
    var hexColor: String {
        switch self {
        case .running: "#34C759"
        case .stopped: "#FF3B30"
        case .paused: "#FF9500"
        case .restarting: "#007AFF"
        case .created: "#8E8E93"
        case .dead: "#FF3B30"
        case .unknown: "#8E8E93"
        }
    }
}
