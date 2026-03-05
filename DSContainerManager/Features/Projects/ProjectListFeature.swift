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
        case actionResult(Result<Void, Error>)
        case detail(PresentationAction<ProjectDetailFeature.Action>)
    }

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

            case .projectsLoaded(.success(let projects)):
                state.isLoading = false
                state.projects = projects
                state.error = nil
                return .none

            case .projectsLoaded(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .projectTapped(let project):
                var detailState = ProjectDetailFeature.State(project: project)
                detailState.baseURL = state.baseURL
                detailState.authSession = state.authSession
                state.detail = detailState
                return .none

            case .projectAction(let project, let action):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                let projectId = project.id.rawValue
                return .run { [baseURL, session] send in
                    try await api.performProjectAction(baseURL, session, projectId, action)
                    try await Task.sleep(for: .seconds(1))
                    await send(.refresh)
                } catch: { error, send in
                    await send(.actionResult(.failure(error)))
                }

            case .actionResult(.failure(let error)):
                state.error = error.localizedDescription
                return .none

            case .actionResult(.success):
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
    }
}
