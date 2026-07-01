import ComposableArchitecture
import SwiftUI

struct ContainerListView: View {
    @Bindable var store: StoreOf<ContainerListFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading, store.containers.isEmpty {
                    List {
                        ForEach(0 ..< 6) { _ in
                            SkeletonRowView()
                        }
                    }
                } else if store.filteredContainers.isEmpty, store.containers.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No Containers",
                        message: "No containers found. Create containers using Container Manager on your Synology NAS.",
                        actionTitle: "Refresh",
                    ) {
                        store.send(.refresh)
                    }
                } else {
                    containerList
                }
            }
            .navigationTitle("Containers")
            .searchable(text: $store.searchText, prompt: "Search containers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    sortMenu
                }
                ToolbarItem(placement: .secondaryAction) {
                    filterMenu
                }
            }
            .refreshable {
                store.send(.refresh)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.stopPolling)
            }
            .navigationDestination(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
                ContainerDetailView(store: detailStore)
            }
            #if os(macOS)
            .keyboardShortcut("f", modifiers: [.command])
            #endif
        }
    }

    private var containerList: some View {
        List {
            if let error = store.error {
                ErrorBannerView(error) {
                    store.send(.refresh)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if let filter = store.statusFilter {
                HStack {
                    Text("Filter: \(filter.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") {
                        store.send(.statusFilterChanged(nil))
                    }
                    .font(.caption)
                }
                .listRowBackground(Color.clear)
            }

            ForEach(store.filteredContainers) { container in
                ContainerRowView(container: container)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.send(.containerTapped(container))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if container.status == .running {
                            Button {
                                store.send(.swipeAction(container, .stop))
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .tint(.red)

                            Button {
                                store.send(.swipeAction(container, .restart))
                            } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }
                            .tint(.orange)
                        } else {
                            Button {
                                store.send(.swipeAction(container, .start))
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            .tint(.green)
                        }
                    }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(ContainerListFeature.State.SortOrder.allCases, id: \.self) { order in
                Button {
                    store.send(.sortOrderChanged(order))
                } label: {
                    HStack {
                        Text(order.rawValue)
                        if store.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("All") {
                store.send(.statusFilterChanged(nil))
            }
            ForEach(ContainerStatus.allCases) { status in
                Button {
                    store.send(.statusFilterChanged(status))
                } label: {
                    HStack {
                        Text(status.displayName)
                        if store.statusFilter == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

#Preview {
    ContainerListView(
        store: Store(initialState: ContainerListFeature.State()) {
            ContainerListFeature()
        },
    )
}
