import ComposableArchitecture
import SwiftUI

struct AppRootView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isConnected {
                #if os(macOS)
                    SidebarNavigationView(store: store)
                #else
                    // A single sidebar-adaptable TabView: tab bar when compact, sidebar when
                    // regular. Keeping one hierarchy means folding/unfolding iPhone Duo (or
                    // resizing on iPad) re-lays out in place instead of rebuilding every tab.
                    MainTabView(store: store)
                #endif
            } else {
                ConnectionListView(
                    store: store.scope(state: \.connectionList, action: \.connectionList),
                )
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    AppRootView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        },
    )
}
