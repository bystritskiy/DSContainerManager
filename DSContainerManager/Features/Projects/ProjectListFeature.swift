import ComposableArchitecture
import Foundation
import Tagged

@Reducer
struct ProjectListFeature {
    @ObservableState
    struct State: Equatable {
        var baseURL: URL?
        var authSession: AuthSession?
        var projects: [ComposeProject] = []
        var pendingActionIDs: Set<String> = []
        var isLoading = false
        var error: String?
        @Presents var detail: ProjectDetailFeature.State?
    }

    enum Action {
        case onAppear
        case refresh
        case projectsLoaded(Result<[ComposeProject], Error>)
        case projectTapped(ComposeProject)
        case projectAction(ComposeProject, ProjectAction)
        case actionResult(String, Result<Void, Error>)
        case detail(PresentationAction<ProjectDetailFeature.Action>)
    }

    enum CancelID: Hashable { case load, action(String) }

    @Dependency(\.synologyClient) var api

    nonisolated var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    state.error = "Not connected"
                    return .none
                }
                state.isLoading = state.projects.isEmpty
                return fetchProjects(baseURL: baseURL, session: session)

            case .refresh:
                state.error = nil
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return fetchProjects(baseURL: baseURL, session: session)

            case let .projectsLoaded(.success(projects)):
                state.isLoading = false
                state.projects = projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                state.error = nil
                return .none

            case let .projectsLoaded(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case let .projectTapped(project):
                var detailState = ProjectDetailFeature.State(project: project)
                detailState.baseURL = state.baseURL
                detailState.authSession = state.authSession
                state.detail = detailState
                return .none

            case let .projectAction(project, action):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                let projectId = project.id.rawValue
                state.pendingActionIDs.insert(projectId)
                return .run { [baseURL, session] send in
                    try await api.performProjectAction(baseURL, session, projectId, action)
                    try await Task.sleep(for: .seconds(1))
                    await send(.refresh)
                    await send(.actionResult(projectId, .success(())))
                } catch: { error, send in
                    await send(.actionResult(projectId, .failure(error)))
                }
                .cancellable(id: CancelID.action(projectId), cancelInFlight: true)

            case let .actionResult(projectId, .failure(error)):
                state.pendingActionIDs.remove(projectId)
                state.error = error.localizedDescription
                return .none

            case let .actionResult(projectId, .success):
                state.pendingActionIDs.remove(projectId)
                return .none

            case let .detail(.presented(.delegate(.projectUpdated(project)))):
                state.projects = state.projects.map { $0.id == project.id ? project : $0 }
                return .none

            case .detail:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            ProjectDetailFeature()
        }
    }

    private func fetchProjects(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            let projects = try await api.listProjects(baseURL, session)
            await send(.projectsLoaded(.success(projects)))
        } catch: { error, send in
            await send(.projectsLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }
}
