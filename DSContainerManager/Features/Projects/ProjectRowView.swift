import SwiftUI

struct ProjectRowView: View {
    let project: ComposeProject

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(project.status.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label("\(project.serviceCount) services", systemImage: "square.stack.3d.up")
                    Label("\(project.containerCount) containers", systemImage: "shippingbox")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadgeView(projectStatus: project.status)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ForEach(ComposeProject.mockList) { project in
            ProjectRowView(project: project)
        }
    }
}
