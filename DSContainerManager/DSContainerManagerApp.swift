import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct DSContainerManagerApp: App {
    static let store: StoreOf<AppFeature> = {
        if DemoMode.isEnabled {
            return makeDemoStore()
        }

        return Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }()

    static func makeDemoStore() -> StoreOf<AppFeature> {
        Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.synologyClient = .mock
            $0.connectionStore = .demoValue
            $0.keychainClient = .demoValue
            $0.backgroundMonitor = .demoValue
        }
    }

    init() {
        @Dependency(\.backgroundMonitor) var backgroundMonitor
        backgroundMonitor.registerTasks()
        setupNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            AppRootSwitcherView()
        }
    }
}

extension EnvironmentValues {
    /// Set by `AppRootSwitcherView`; views call it to enter the sample-data demo session.
    @Entry var startDemoMode: () -> Void = {}
}

/// Swaps between the live store and an on-demand demo store (mock dependencies).
/// Disconnecting inside the demo returns to the live connection list.
private struct AppRootSwitcherView: View {
    @State private var demoStore: StoreOf<AppFeature>?

    var body: some View {
        if let demoStore {
            AppRootView(store: demoStore)
                .onChange(of: demoStore.isConnected) { _, isConnected in
                    if !isConnected {
                        self.demoStore = nil
                    }
                }
        } else {
            AppRootView(store: DSContainerManagerApp.store)
                .environment(\.startDemoMode) {
                    demoStore = DSContainerManagerApp.makeDemoStore()
                }
        }
    }
}
