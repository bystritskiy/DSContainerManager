import ComposableArchitecture
import SwiftUI

struct ProjectListView: View {
    @Bindable var store: StoreOf<ProjectListFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading, store.projects.isEmpty {
                    List {
                        ForEach(0 ..< 4) { _ in
                            SkeletonRowView()
                        }
                    }
                } else if store.projects.isEmpty {
                    EmptyStateView(
                        icon: "folder",
                        title: "No Projects",
                        message: "No Compose projects found. Create projects using Container Manager on your Synology NAS.",
                        actionTitle: "Refresh",
                    ) {
                        store.send(.refresh)
                    }
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .refreshable {
                store.send(.refresh)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .navigationDestination(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
                ProjectDetailView(store: detailStore)
            }
        }
    }

    private var projectList: some View {
        List {
            if let error = store.error {
                ErrorBannerView(error) {
                    store.send(.refresh)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            ForEach(store.projects) { project in
                Button {
                    store.send(.projectTapped(project))
                } label: {
                    ProjectRowView(project: project)
                }
                .buttonStyle(FluidPressButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if project.status == .running || project.status == .partiallyRunning {
                        Button {
                            store.send(.projectAction(project, .stop))
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .tint(.red)

                        Button {
                            store.send(.projectAction(project, .restart))
                        } label: {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        .tint(.orange)
                    } else {
                        Button {
                            store.send(.projectAction(project, .start))
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .tint(.green)
                    }
                }
            }
        }
    }
}

#Preview {
    ProjectListView(
        store: Store(initialState: ProjectListFeature.State()) {
            ProjectListFeature()
        },
    )
}
