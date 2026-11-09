import Dependencies
import DependenciesMacros
import Foundation
import WidgetKit

// MARK: - Widget Data Client

/// Publishes dashboard data to the home-screen widget through the shared App Group.
@DependencyClient
struct WidgetDataClient {
    var update: @Sendable (_ data: SharedContainerData) -> Void
    var clear: @Sendable () -> Void
}

extension WidgetDataClient: DependencyKey {
    static let liveValue = WidgetDataClient(
        update: { data in
            SharedStorage.saveContainerData(data)
            WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)
        },
        clear: {
            SharedStorage.clearContainerData()
            WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)
        },
    )

    static let previewValue = WidgetDataClient(update: { _ in }, clear: {})
}

extension WidgetDataClient: TestDependencyKey {
    static let testValue = previewValue
}

extension DependencyValues {
    var widgetData: WidgetDataClient {
        get { self[WidgetDataClient.self] }
        set { self[WidgetDataClient.self] = newValue }
    }
}

// MARK: - Snapshot Mapping

extension SharedContainerData {
    init(
        nasName: String,
        containers: [DockerContainer],
        cpuPercent: Double,
        memoryPercent: Double,
        timestamp: Date = .now,
    ) {
        // Running first, so the widget's short list shows what is actually up.
        let ordered = containers.filter { $0.status == .running } + containers.filter { $0.status != .running }
        self.init(
            timestamp: timestamp,
            nasName: nasName,
            containers: ordered.map {
                SharedContainerInfo(id: $0.id.rawValue, name: $0.name, image: $0.image, status: $0.status.rawValue)
            },
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            runningCount: containers.count(where: { $0.status == .running }),
            stoppedCount: containers.count(where: { $0.status == .stopped }),
            totalCount: containers.count,
        )
    }
}
