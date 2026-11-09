import ComposableArchitecture
import SwiftUI

// MARK: - Tab View (iPhone; adapts to a sidebar on wide displays)

struct MainTabView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            Tab("Dashboard", systemImage: "gauge.medium", value: AppFeature.State.Tab.dashboard) {
                DashboardView(
                    store: store.scope(state: \.dashboard, action: \.dashboard),
                )
            }

            Tab("Containers", systemImage: "shippingbox", value: AppFeature.State.Tab.containers) {
                ContainerListView(
                    store: store.scope(state: \.containerList, action: \.containerList),
                )
            }

            Tab("Projects", systemImage: "folder", value: AppFeature.State.Tab.projects) {
                ProjectListView(
                    store: store.scope(state: \.projectList, action: \.projectList),
                )
            }

            Tab("Monitor", systemImage: "chart.xyaxis.line", value: AppFeature.State.Tab.monitor) {
                SystemMonitorView(
                    store: store.scope(state: \.systemMonitor, action: \.systemMonitor),
                )
            }

            Tab("Settings", systemImage: "gear", value: AppFeature.State.Tab.settings) {
                SettingsView(store: store)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sensoryFeedback(.selection, trigger: store.selectedTab)
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        },
    )
}

#Preview("Duo inner display", traits: .fixedLayout(width: 951, height: 669)) {
    MainTabView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        },
    )
}
