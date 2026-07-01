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

#Preview {
    AppRootView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
