import SwiftUI

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel("Status: \(title)")
    }
}

// MARK: - Convenience initializers

extension StatusBadge {
    init(containerStatus: ContainerStatus) {
        self.init(title: containerStatus.displayName, color: containerStatus.color)
    }

    init(projectStatus: ProjectStatus) {
        self.init(title: projectStatus.displayName, color: projectStatus.color)
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(containerStatus: .running)
        StatusBadge(containerStatus: .stopped)
        StatusBadge(containerStatus: .paused)
        StatusBadge(containerStatus: .restarting)
        StatusBadge(projectStatus: .partiallyRunning)
    }
    .padding()
}
