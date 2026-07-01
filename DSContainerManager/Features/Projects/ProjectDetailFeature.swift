import ComposableArchitecture
import Foundation
import Tagged

enum ProjectDetailTab: String, CaseIterable {
    case services = "Services"
    case compose = "Compose"
    case info = "Info"
}

@Reducer
struct ProjectDetailFeature {
    @ObservableState
    struct State: Equatable {
        let projectId: String
        var project: ComposeProject
        var baseURL: URL?
        var authSession: AuthSession?
        var isPerformingAction = false
        var error: String?
        var selectedTab: ProjectDetailTab = .services

        init(project: ComposeProject) {
            projectId = project.id.rawValue
            self.project = project
        }
    }

    enum Action {
        case refreshProject
        case tabSelected(ProjectDetailTab)
        case actionTapped(ProjectAction)
        case actionResult(Result<Void, Error>)
        case projectLoaded(Result<ComposeProject, Error>)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case projectUpdated(ComposeProject)
    }

    enum CancelID { case load, action }

    @Dependency(\.synologyClient) var api

    nonisolated var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .refreshProject:
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return fetchProject(baseURL: baseURL, session: session, projectId: state.projectId)

            case let .actionTapped(projectAction):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                state.isPerformingAction = true
                state.error = nil
                let projectId = state.project.id.rawValue
                return .run { [baseURL, session] send in
                    try await api.performProjectAction(baseURL, session, projectId, projectAction)
                    await send(.refreshProject)
                } catch: { error, send in
                    await send(.actionResult(.failure(error)))
                }
                .cancellable(id: CancelID.action, cancelInFlight: true)

            case let .projectLoaded(.success(project)):
                state.project = project
                state.isPerformingAction = false
                state.error = nil
                return .send(.delegate(.projectUpdated(project)))

            case let .projectLoaded(.failure(error)):
                state.isPerformingAction = false
                state.error = error.localizedDescription
                return .none

            case .actionResult(.success):
                state.isPerformingAction = false
                return .none

            case let .actionResult(.failure(error)):
                state.isPerformingAction = false
                state.error = error.localizedDescription
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func fetchProject(baseURL: URL, session: AuthSession, projectId: String) -> Effect<Action> {
        .run { send in
            let project = try await api.getProjectDetail(baseURL, session, projectId)
            await send(.projectLoaded(.success(project)))
        } catch: { error, send in
            await send(.projectLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }
}

extension ProjectDetailFeature.State: Identifiable {
    nonisolated var id: String {
        projectId
    }
}
