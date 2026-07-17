import ComposableArchitecture
import SwiftUI

// MARK: - Sidebar Navigation (iPad / macOS)

struct SidebarNavigationView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { store.selectedTab },
                set: { tab in
                    if let tab {
                        store.send(.tabSelected(tab))
                    }
                },
            )) {
                ForEach(AppFeature.State.Tab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
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

#Preview {
    SidebarNavigationView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        },
    )
}
