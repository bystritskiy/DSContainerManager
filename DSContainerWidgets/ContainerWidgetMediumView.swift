import SwiftUI
import WidgetKit

struct ContainerWidgetMediumView: View {
    let data: SharedContainerData

    private let maxListed = 5

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ContainerWidgetSmallView(data: data)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(data.containers.prefix(maxListed)) { container in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(WidgetStatusColor.color(for: container.status))
                            .frame(width: 6, height: 6)
                        Text(container.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                if data.containers.count > maxListed {
                    Text("+\(data.containers.count - maxListed) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
