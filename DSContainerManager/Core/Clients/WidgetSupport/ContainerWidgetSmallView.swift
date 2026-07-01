import SwiftUI
import WidgetKit

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

#Preview {
    ContainerWidgetSmallView(entry: .placeholder)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
}
