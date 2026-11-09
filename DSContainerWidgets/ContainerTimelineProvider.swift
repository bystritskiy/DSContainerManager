import Foundation
import WidgetKit

// MARK: - Timeline Provider

/// Reads the snapshot the app last wrote to the App Group. The app reloads the timeline
/// whenever it refreshes the dashboard, so the widget never talks to the NAS itself.
struct ContainerTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> ContainerWidgetEntry {
        ContainerWidgetEntry(date: .now, data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ContainerWidgetEntry) -> Void) {
        let data = SharedStorage.loadContainerData() ?? (context.isPreview ? .preview : nil)
        completion(ContainerWidgetEntry(date: .now, data: data))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ContainerWidgetEntry>) -> Void) {
        let entry = ContainerWidgetEntry(date: .now, data: SharedStorage.loadContainerData())
        // Re-render periodically so the "updated … ago" label stays honest.
        let nextUpdate = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Entry

struct ContainerWidgetEntry: TimelineEntry {
    let date: Date
    /// `nil` until the app has connected to a NAS at least once.
    let data: SharedContainerData?
}

// MARK: - Preview Data

extension SharedContainerData {
    static let preview = SharedContainerData(
        timestamp: .now.addingTimeInterval(-120),
        nasName: "Home NAS",
        containers: [
            SharedContainerInfo(id: "1", name: "plex", image: "plexinc/pms-docker", status: "running"),
            SharedContainerInfo(id: "2", name: "pihole", image: "pihole/pihole", status: "running"),
            SharedContainerInfo(id: "3", name: "homeassistant", image: "home-assistant", status: "running"),
            SharedContainerInfo(id: "4", name: "nextcloud", image: "nextcloud", status: "stopped"),
        ],
        cpuPercent: 23.5,
        memoryPercent: 41.2,
        runningCount: 6,
        stoppedCount: 2,
        totalCount: 8,
    )
}
