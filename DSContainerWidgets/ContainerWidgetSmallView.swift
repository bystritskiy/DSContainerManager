import SwiftUI
import WidgetKit

struct ContainerWidgetSmallView: View {
    let data: SharedContainerData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(data.nasName, systemImage: "server.rack")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("\(data.runningCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .contentTransition(.numericText())
            Text("of \(data.totalCount) running")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            WidgetUsageLine(cpuPercent: data.cpuPercent, memoryPercent: data.memoryPercent)
            WidgetUpdatedLabel(timestamp: data.timestamp)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
