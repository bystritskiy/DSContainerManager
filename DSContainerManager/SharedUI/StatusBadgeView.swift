import SwiftUI

struct StatusBadgeView: View {
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

extension StatusBadgeView {
    init(containerStatus: ContainerStatus) {
        self.init(title: containerStatus.displayName, color: containerStatus.color)
    }

    init(projectStatus: ProjectStatus) {
        self.init(title: projectStatus.displayName, color: projectStatus.color)
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadgeView(containerStatus: .running)
        StatusBadgeView(containerStatus: .stopped)
        StatusBadgeView(containerStatus: .paused)
        StatusBadgeView(containerStatus: .restarting)
        StatusBadgeView(projectStatus: .partiallyRunning)
    }
    .padding()
}
