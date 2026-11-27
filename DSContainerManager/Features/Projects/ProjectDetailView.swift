import ComposableArchitecture
import SwiftUI

struct ProjectDetailView: View {
    @Bindable var store: StoreOf<ProjectDetailFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingStopConfirmation = false

    private var isActive: Bool {
        store.project.status == .running || store.project.status == .partiallyRunning
    }

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
            .id(store.selectedTab)
            .transition(.opacity)
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.15)
                : .spring(response: 0.32, dampingFraction: 1),
            value: store.selectedTab,
        )
        .sensoryFeedback(.selection, trigger: store.selectedTab)
        .navigationTitle(store.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.isPerformingAction {
                    ProgressView()
                } else {
                    actionsMenu
                }
            }
            if store.selectedTab == .compose, let content = store.project.composeContent {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: content) {
                        Label("Share Compose File", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .confirmationDialog(
            "Stop \(store.project.name)?",
            isPresented: $showingStopConfirmation,
            titleVisibility: .visible,
        ) {
            Button("Stop Project", role: .destructive) {
                store.send(.actionTapped(.stop))
            }
        } message: {
            Text("All of its containers will stop.")
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var actionsMenu: some View {
        Menu {
            if isActive {
                Button {
                    store.send(.actionTapped(.restart))
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    showingStopConfirmation = true
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
            if store.project.status != .running {
                // A partially running project can be started to bring up the rest.
                Button {
                    store.send(.actionTapped(.start))
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
    }

    // MARK: - Services Tab

    private var servicesTab: some View {
        List {
            if let error = store.error {
                ErrorBannerView(error)
            }

            ForEach(store.project.services) { service in
                HStack(spacing: 12) {
                    // Status dot: play/stop glyphs here read as start/stop buttons.
                    Circle()
                        .fill(service.status?.color ?? .gray)
                        .frame(width: 10, height: 10)
                        .frame(width: 16)

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
                        StatusBadgeView(containerStatus: status)
                    }
                }
            }

            if store.project.services.isEmpty {
                ContentUnavailableView(
                    "No Services",
                    systemImage: "square.stack.3d.up",
                    description: Text("This project has no services defined."),
                )
            }
        }
        .refreshable {
            await store.send(.refreshProject).finish()
        }
    }

    // MARK: - Compose Tab

    @ViewBuilder
    private var composeTab: some View {
        if let content = store.project.composeContent {
            // Scroll sideways instead of wrapping, so YAML indentation stays readable.
            ScrollView([.vertical, .horizontal]) {
                Text(content)
                    .font(.system(.footnote, design: .monospaced))
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .background(Color(.systemBackground))
        } else {
            EmptyStateView(
                icon: "doc.text",
                title: "No Compose File",
                message: "The compose file content is not available for this project.",
            )
        }
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        List {
            Section {
                LabeledContent("Status", value: store.project.status.displayName)
                if !store.project.path.isEmpty {
                    LabeledContent("Path", value: store.project.path)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = store.project.path
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                }
                if !store.project.sharePath.isEmpty {
                    LabeledContent("Shared Folder", value: store.project.sharePath)
                }
                if store.project.containerCount > 0 {
                    LabeledContent("Containers", value: "\(store.project.containerCount)")
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
                    project: ComposeProject.mockList[0],
                ),
            ) {
                ProjectDetailFeature()
            },
        )
    }
}
