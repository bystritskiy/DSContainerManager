import SwiftUI
import WidgetKit

// MARK: - Widget Timeline Provider

struct ContainerTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = ContainerWidgetEntry
    typealias Intent = ContainerWidgetIntent

    func placeholder(in context: Context) -> ContainerWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: Intent, in context: Context) async -> ContainerWidgetEntry {
        loadEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<ContainerWidgetEntry> {
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

import AppIntents

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

// MARK: - Small Widget View

struct ContainerWidgetSmallView: View {
    let entry: ContainerWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.blue)
                Text("Containers")
                    .font(.caption.bold())
            }

            Spacer()

            HStack(spacing: 12) {
                VStack {
                    Text("\(entry.runningCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("Running")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(entry.stoppedCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                    Text("Stopped")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Medium Widget View

struct ContainerWidgetMediumView: View {
    let entry: ContainerWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Summary
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(.blue)
                    Text("Containers")
                        .font(.caption.bold())
                }

                Spacer()

                HStack(spacing: 16) {
                    statItem(count: entry.runningCount, label: "Running", color: .green)
                    statItem(count: entry.stoppedCount, label: "Stopped", color: .red)
                    statItem(count: entry.totalCount, label: "Total", color: .primary)
                }

                Spacer()

                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Right: Top containers
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.containers.prefix(4)) { container in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: container.statusColor) ?? .gray)
                            .frame(width: 6, height: 6)
                        Text(container.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                if entry.containers.count > 4 {
                    Text("+\(entry.containers.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private func statItem(count: Int, label: String, color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
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
