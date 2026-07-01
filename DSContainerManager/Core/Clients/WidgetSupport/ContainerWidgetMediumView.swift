import SwiftUI
import WidgetKit

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

#Preview {
    ContainerWidgetMediumView(entry: .placeholder)
        .previewContext(WidgetPreviewContext(family: .systemMedium))
}
