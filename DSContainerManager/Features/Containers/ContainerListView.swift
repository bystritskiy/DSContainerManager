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
                } else if store.containers.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No Containers",
                        message: "No containers found. Create containers using Container Manager on your Synology NAS.",
                        actionTitle: "Refresh",
                    ) {
                        store.send(.refresh)
                    }
                } else if store.filteredContainers.isEmpty {
                    filteredEmptyState
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
                Button {
                    store.send(.containerTapped(container))
                } label: {
                    ContainerRowView(container: container)
                }
                .buttonStyle(FluidPressButtonStyle())
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

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("No Matching Containers", systemImage: "magnifyingglass")
        } description: {
            if !store.searchText.isEmpty {
                Text("No containers match \u{201c}\(store.searchText)\u{201d}.")
            } else if let filter = store.statusFilter {
                Text("No containers have the \(filter.displayName.lowercased()) status.")
            }
        } actions: {
            Button("Clear Search and Filters") {
                store.send(.statusFilterChanged(nil))
                store.searchText = ""
            }
            .buttonStyle(.borderedProminent)
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
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
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
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.iconOnly)
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
