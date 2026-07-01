import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Timeline Provider

struct ContainerTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = ContainerWidgetEntry
    typealias Intent = ContainerWidgetIntent

    func placeholder(in _: Context) -> ContainerWidgetEntry {
        .placeholder
    }

    func snapshot(for _: Intent, in _: Context) async -> ContainerWidgetEntry {
        loadEntry()
    }

    func timeline(for _: Intent, in _: Context) async -> Timeline<ContainerWidgetEntry> {
        let entry = loadEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func loadEntry() -> ContainerWidgetEntry {
        guard let data = SharedStorage.loadContainerData() else {
            return .placeholder
        }
        return ContainerWidgetEntry(
            date: data.timestamp,
            containers: data.containers,
            cpuPercent: data.cpuPercent,
            memoryPercent: data.memoryPercent,
            runningCount: data.runningCount,
            stoppedCount: data.stoppedCount,
            totalCount: data.totalCount
        )
    }
}

// MARK: - Widget Intent

struct ContainerWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Container Status"
    static var description: IntentDescription = "Shows the status of your Docker containers"
}

// MARK: - Widget Entry

struct ContainerWidgetEntry: TimelineEntry {
    let date: Date
    let containers: [SharedContainerInfo]
    let cpuPercent: Double
    let memoryPercent: Double
    let runningCount: Int
    let stoppedCount: Int
    let totalCount: Int

    static let placeholder = ContainerWidgetEntry(
        date: .now,
        containers: [
            SharedContainerInfo(id: "1", name: "plex", image: "plexinc/pms-docker", status: "running", statusColor: "#34C759"),
            SharedContainerInfo(id: "2", name: "pihole", image: "pihole/pihole", status: "running", statusColor: "#34C759"),
            SharedContainerInfo(id: "3", name: "homeassistant", image: "ghcr.io/home-assistant/home-assistant", status: "stopped", statusColor: "#FF3B30"),
        ],
        cpuPercent: 23.5,
        memoryPercent: 67.2,
        runningCount: 6,
        stoppedCount: 2,
        totalCount: 8
    )
}

// MARK: - Color from Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
