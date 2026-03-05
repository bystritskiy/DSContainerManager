import ComposableArchitecture
import Foundation
import Tagged

enum ProjectDetailTab: String, CaseIterable, Sendable {
    case services = "Services"
    case compose = "Compose"
    case info = "Info"
}

@Reducer
struct ProjectDetailFeature {
    @ObservableState
    struct State: Equatable {
        let projectId: String
        let project: ComposeProject
        var baseURL: URL?
        var authSession: AuthSession?
        var isPerformingAction = false
        var error: String?
        var selectedTab: ProjectDetailTab = .services

        init(project: ComposeProject) {
            self.projectId = project.id.rawValue
            self.project = project
        }
    }

    enum Action {
        case tabSelected(ProjectDetailTab)
        case actionTapped(ProjectAction)
        case actionResult(Result<Void, Error>)
    }

    @Dependency(\.synologyClient) var api

    nonisolated var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .actionTapped(let projectAction):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                state.isPerformingAction = true
                state.error = nil
                let projectId = state.project.id.rawValue
                return .run { [baseURL, session] send in
                    try await api.performProjectAction(baseURL, session, projectId, projectAction)
                    await send(.actionResult(.success(())))
                } catch: { error, send in
                    await send(.actionResult(.failure(error)))
                }

            case .actionResult(.success):
                state.isPerformingAction = false
                return .none

            case .actionResult(.failure(let error)):
                state.isPerformingAction = false
                state.error = error.localizedDescription
                return .none
            }
        }
    }
}

extension ProjectDetailFeature.State: Identifiable {
    nonisolated var id: String { projectId }
}
