import ComposableArchitecture
import SwiftUI

struct AppRootView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if store.isConnected {
                #if os(macOS)
                SidebarNavigationView(store: store)
                #else
                if horizontalSizeClass == .regular {
                    SidebarNavigationView(store: store)
                } else {
                    MainTabView(store: store)
                }
                #endif
            } else {
                ConnectionListView(
                    store: store.scope(state: \.connectionList, action: \.connectionList)
                )
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - Tab View (iPhone Compact)

struct MainTabView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            Tab("Dashboard", systemImage: "gauge.medium", value: AppFeature.State.Tab.dashboard) {
                DashboardView(
                    store: store.scope(state: \.dashboard, action: \.dashboard)
                )
            }

            Tab("Containers", systemImage: "shippingbox", value: AppFeature.State.Tab.containers) {
                ContainerListView(
                    store: store.scope(state: \.containerList, action: \.containerList)
                )
            }

            Tab("Projects", systemImage: "folder", value: AppFeature.State.Tab.projects) {
                ProjectListView(
                    store: store.scope(state: \.projectList, action: \.projectList)
                )
            }

            Tab("Monitor", systemImage: "chart.xyaxis.line", value: AppFeature.State.Tab.monitor) {
                SystemMonitorView(
                    store: store.scope(state: \.systemMonitor, action: \.systemMonitor)
                )
            }

            Tab("Settings", systemImage: "gear", value: AppFeature.State.Tab.settings) {
                SettingsView(store: store)
            }
        }
    }
}

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
                            : Color.clear
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
                store: store.scope(state: \.dashboard, action: \.dashboard)
            )
        case .containers:
            ContainerListView(
                store: store.scope(state: \.containerList, action: \.containerList)
            )
        case .projects:
            ProjectListView(
                store: store.scope(state: \.projectList, action: \.projectList)
            )
        case .monitor:
            SystemMonitorView(
                store: store.scope(state: \.systemMonitor, action: \.systemMonitor)
            )
        case .settings:
            SettingsView(store: store)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            List {
                if let connection = store.activeConnection {
                    Section("Connected NAS") {
                        LabeledContent("Name", value: connection.name)
                            .accessibilityLabel("NAS Name: \(connection.name)")
                        LabeledContent("Host", value: "\(connection.host):\(connection.port)")
                            .accessibilityLabel("Host: \(connection.host), Port: \(connection.port)")
                        LabeledContent("User", value: connection.username)
                            .accessibilityLabel("Username: \(connection.username)")
                        if let lastConnected = connection.lastConnected {
                            LabeledContent("Connected", value: lastConnected.relativeString)
                                .accessibilityLabel("Last connected \(lastConnected.relativeString)")
                        }
                    }
                }

                Section {
                    Button("Disconnect", role: .destructive) {
                        store.send(.disconnect)
                    }
                    .accessibilityHint("Disconnect from the current NAS")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    AppRootView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
