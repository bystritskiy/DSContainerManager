import SwiftUI

struct ProjectRowView: View {
    let project: ComposeProject
    var isPending = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes a side-by-side row squeezes the name; stack everything instead.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                details
                status
            }
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundStyle(project.status.color)
                    .frame(width: 28)

                details

                Spacer()

                status
            }
            .padding(.vertical, 4)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.body)
                .fontWeight(.medium)

            // The project list endpoint can omit services, so zero means "unknown" — hide it.
            if let summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if isPending {
            ProgressView()
        } else {
            StatusBadgeView(projectStatus: project.status)
        }
    }

    private var summary: String? {
        var parts: [String] = []
        if project.serviceCount > 0 {
            parts.append(Self.count(project.serviceCount, "service"))
        }
        if project.containerCount > 0 {
            parts.append(Self.count(project.containerCount, "container"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }
}

#Preview {
    List {
        ForEach(ComposeProject.mockList) { project in
            ProjectRowView(project: project)
        }
    }
}
