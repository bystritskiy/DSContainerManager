import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct DSContainerManagerApp: App {
    static let store: StoreOf<AppFeature> = {
        if DemoMode.isEnabled {
            return Store(initialState: AppFeature.State()) {
                AppFeature()
            } withDependencies: {
                $0.synologyClient = .mock
                $0.connectionStore = .demoValue
                $0.keychainClient = .demoValue
            }
        }

        return Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }()

    init() {
        @Dependency(\.backgroundMonitor) var backgroundMonitor
        backgroundMonitor.registerTasks()
        setupNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: DSContainerManagerApp.store)
        }
    }
}
