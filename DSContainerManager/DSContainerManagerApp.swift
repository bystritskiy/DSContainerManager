import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct DSContainerManagerApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

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
