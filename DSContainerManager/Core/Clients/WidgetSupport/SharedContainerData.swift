import Foundation

// MARK: - Shared Data for Widget Extension

// Compiled into both the app and the DSContainerWidgets extension (see the target
// membership exception in project.pbxproj), so it must not reference app-only types.

/// Snapshot the app writes after each dashboard refresh; the widget only reads it.
struct SharedContainerData: Codable, Equatable {
    let timestamp: Date
    let nasName: String
    let containers: [SharedContainerInfo]
    let cpuPercent: Double
    let memoryPercent: Double
    let runningCount: Int
    let stoppedCount: Int
    let totalCount: Int
}

struct SharedContainerInfo: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let image: String
    /// `ContainerStatus.rawValue` — kept as a string so the widget needs no app model types.
    let status: String
}

// MARK: - App Group Storage

enum SharedStorage {
    static let appGroupIdentifier = "group.com.bystritski.DSContainerManager"
    static let containerDataKey = "containerData"
    static let widgetKind = "ContainerStatusWidget"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func saveContainerData(_ data: SharedContainerData) {
        guard let defaults = sharedDefaults,
              let encoded = try? JSONEncoder().encode(data)
        else {
            return
        }
        defaults.set(encoded, forKey: containerDataKey)
    }

    static func loadContainerData() -> SharedContainerData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: containerDataKey)
        else {
            return nil
        }
        return try? JSONDecoder().decode(SharedContainerData.self, from: data)
    }

    static func clearContainerData() {
        sharedDefaults?.removeObject(forKey: containerDataKey)
    }
}
