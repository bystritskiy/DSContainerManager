import SwiftUI

struct ContainerRowView: View {
    let container: DockerContainer

    var body: some View {
        HStack(spacing: 12) {
            // Status dot: play/stop glyphs here read as start/stop buttons, the opposite of their meaning.
            Circle()
                .fill(container.status.color)
                .frame(width: 10, height: 10)
                .frame(width: 16)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(container.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !container.ports.isEmpty {
                    Text(container.ports.map(\.displayString).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status badge + time
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadgeView(containerStatus: container.status)

                Text(container.created.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(container.name), \(container.status.displayName)")
        .accessibilityHint("Double tap to view details")
    }
}

#Preview {
    List {
        ForEach(DockerContainer.mockList) { container in
            ContainerRowView(container: container)
        }
    }
}
