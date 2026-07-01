import ComposableArchitecture
import SwiftUI

// MARK: - Sidebar Navigation (iPad / macOS)

struct SidebarNavigationView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(AppFeature.State.Tab.allCases, id: \.self) { tab in
                    Button {
                        store.send(.tabSelected(tab))
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .listRowBackground(
                        store.selectedTab == tab
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear,
                    )
                }
            }
            .navigationTitle("DS Container")
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            #endif
        } detail: {
            detailView
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    store.send(.dashboard(.refresh))
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh current view (Cmd+R)")
            }
        }
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selectedTab {
        case .dashboard:
            DashboardView(
                store: store.scope(state: \.dashboard, action: \.dashboard),
            )
        case .containers:
            ContainerListView(
                store: store.scope(state: \.containerList, action: \.containerList),
            )
        case .projects:
            ProjectListView(
                store: store.scope(state: \.projectList, action: \.projectList),
            )
        case .monitor:
            SystemMonitorView(
                store: store.scope(state: \.systemMonitor, action: \.systemMonitor),
            )
        case .settings:
            SettingsView(store: store)
        }
    }
}
