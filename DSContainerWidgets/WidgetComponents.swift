import SwiftUI

/// Status dot colors, matching `ContainerStatus.color` in the app.
enum WidgetStatusColor {
    static func color(for status: String) -> Color {
        switch status {
        case "running": .green
        case "stopped", "dead": .red
        case "paused": .orange
        case "restarting": .blue
        default: .gray
        }
    }
}

struct WidgetUsageLine: View {
    let cpuPercent: Double
    let memoryPercent: Double

    var body: some View {
        HStack(spacing: 8) {
            Text("CPU \(Int(cpuPercent.rounded()))%")
            Text("RAM \(Int(memoryPercent.rounded()))%")
        }
        .font(.caption2.weight(.medium))
        .monospacedDigit()
        .lineLimit(1)
    }
}

/// The widget only shows what the app last fetched, so always say how old it is.
struct WidgetUpdatedLabel: View {
    let timestamp: Date

    var body: some View {
        Text("Updated \(timestamp, style: .relative) ago")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}
