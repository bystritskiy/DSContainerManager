import SwiftUI
import WidgetKit

struct ContainerStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStorage.widgetKind, provider: ContainerTimelineProvider()) { entry in
            ContainerStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Containers")
        .description("Running and stopped containers, CPU and memory of your NAS.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ContainerStatusWidgetView: View {
    let entry: ContainerWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let data = entry.data {
                switch family {
                case .systemMedium:
                    ContainerWidgetMediumView(data: data)
                default:
                    ContainerWidgetSmallView(data: data)
                }
            } else {
                notConnectedView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var notConnectedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "shippingbox")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open DSContainer to connect to your NAS")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview(as: .systemSmall) {
    ContainerStatusWidget()
} timeline: {
    ContainerWidgetEntry(date: .now, data: .preview)
    ContainerWidgetEntry(date: .now, data: nil)
}

#Preview(as: .systemMedium) {
    ContainerStatusWidget()
} timeline: {
    ContainerWidgetEntry(date: .now, data: .preview)
}
