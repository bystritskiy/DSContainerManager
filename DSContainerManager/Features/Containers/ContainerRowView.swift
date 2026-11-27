import SwiftUI

struct ContainerRowView: View {
    let container: DockerContainer
    var isPending = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            // At accessibility sizes a side-by-side row squeezes the name; stack everything instead.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    details
                    HStack(spacing: 8) {
                        status
                    }
                }
            } else {
                HStack(spacing: 12) {
                    // Status dot: play/stop glyphs here read as start/stop buttons, the opposite of their meaning.
                    Circle()
                        .fill(container.status.color)
                        .frame(width: 10, height: 10)
                        .frame(width: 16)

                    details

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        status
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(container.name), \(container.status.displayName)")
        .accessibilityHint("Double tap to view details")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(container.name)
                .font(.body)
                .fontWeight(.medium)

            Text(container.image)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            if !container.ports.isEmpty {
                Text(container.ports.map(\.displayString).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
        }
    }

    /// Status badge + time; a start/stop in flight replaces them until the NAS reports back.
    @ViewBuilder
    private var status: some View {
        if isPending {
            ProgressView()
        } else {
            StatusBadgeView(containerStatus: container.status)

            Text(container.created.relativeString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    List {
        ForEach(DockerContainer.mockList) { container in
            ContainerRowView(container: container)
        }
    }
}
