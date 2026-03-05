import ComposableArchitecture
import SwiftUI

struct ProjectDetailView: View {
    @Bindable var store: StoreOf<ProjectDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $store.selectedTab.sending(\.tabSelected)) {
                ForEach(ProjectDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch store.selectedTab {
                case .services:
                    servicesTab
                case .compose:
                    composeTab
                case .info:
                    infoTab
                }
            }
        }
        .navigationTitle(store.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.project.status == .running || store.project.status == .partiallyRunning {
                    Button {
                        store.send(.actionTapped(.stop))
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .tint(.red)
                } else {
                    Button {
                        store.send(.actionTapped(.start))
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .tint(.green)
                }
            }
        }
    }

    // MARK: - Services Tab

    private var servicesTab: some View {
        List {
            if let error = store.error {
                ErrorBanner(error)
            }

            ForEach(store.project.services) { service in
                HStack(spacing: 12) {
                    Image(systemName: service.status?.iconName ?? "questionmark.circle")
                        .foregroundStyle(service.status?.color ?? .gray)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.displayName)
                            .font(.body)
                            .fontWeight(.medium)

                        if let image = service.image {
                            Text(image)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if let status = service.status {
                        StatusBadge(containerStatus: status)
                    }
                }
            }

            if store.project.services.isEmpty {
                ContentUnavailableView(
                    "No Services",
                    systemImage: "square.stack.3d.up",
                    description: Text("This project has no services defined.")
                )
            }
        }
    }

    // MARK: - Compose Tab

    private var composeTab: some View {
        Group {
            if let content = store.project.composeContent {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .background(Color(.systemBackground))
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Compose File",
                    message: "The compose file content is not available for this project."
                )
            }
        }
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        List {
            Section("Project") {
                LabeledContent("Name", value: store.project.name)
                LabeledContent("Status", value: store.project.status.displayName)
                LabeledContent("Path", value: store.project.path)
                LabeledContent("Share Path", value: store.project.sharePath)
                LabeledContent("Version", value: "\(store.project.version)")
            }

            Section("Containers") {
                ForEach(store.project.containerIds, id: \.self) { containerId in
                    Label(containerId, systemImage: "shippingbox")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(
            store: Store(
                initialState: ProjectDetailFeature.State(
                    project: ComposeProject.mockList[0]
                )
            ) {
                ProjectDetailFeature()
            }
        )
    }
}
