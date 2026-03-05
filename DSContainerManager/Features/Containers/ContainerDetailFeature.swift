import ComposableArchitecture
import Foundation
import Tagged

enum ContainerDetailTab: String, CaseIterable, Sendable {
    case info = "Info"
    case logs = "Logs"
    case resources = "Resources"
    case actions = "Actions"
}

@Reducer
struct ContainerDetailFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: String
        let container: DockerContainer
        var baseURL: URL?
        var authSession: AuthSession?

        init(container: DockerContainer, detail: ContainerDetail? = nil) {
            self.id = container.id.rawValue
            self.container = container
            self.detail = detail
        }
        var detail: ContainerDetail?
        var logs: [ContainerLog] = []
        var resourceHistory: [ResourceSnapshot] = []
        var currentResources: ContainerResources?
        var selectedTab: ContainerDetailTab = .info
        var isLoading = false
        var isPerformingAction = false
        var error: String?
        var logSearchText: String = ""

        var filteredLogs: [ContainerLog] {
            guard !logSearchText.isEmpty else { return logs }
            return logs.filter { $0.text.localizedCaseInsensitiveContains(logSearchText) }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case tabSelected(ContainerDetailTab)
        case detailLoaded(Result<ContainerDetail, Error>)
        case logsLoaded(Result<[ContainerLog], Error>)
        case resourcesLoaded(Result<[ContainerResources], Error>)
        case actionTapped(ContainerAction)
        case actionResult(Result<Void, Error>)
        case startResourcePolling
        case stopResourcePolling
        case resourcePollTick
        case loadMoreLogs
    }

    private enum CancelID { case resourcePolling }

    @Dependency(\.synologyClient) var api
    @Dependency(\.continuousClock) var clock

    nonisolated var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    state.error = "Not connected"
                    return .none
                }
                state.isLoading = true
                let name = state.container.name
                return .merge(
                    .run { [baseURL, session] send in
                        let detail = try await api.getContainerDetail(baseURL, session, name)
                        await send(.detailLoaded(.success(detail)))
                    } catch: { error, send in
                        await send(.detailLoaded(.failure(error)))
                    },
                    .run { [baseURL, session] send in
                        let logs = try await api.getContainerLogs(baseURL, session, name, 0, 100)
                        await send(.logsLoaded(.success(logs)))
                    } catch: { error, send in
                        await send(.logsLoaded(.failure(error)))
                    },
                    .send(.startResourcePolling)
                )

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .detailLoaded(.success(let detail)):
                state.detail = detail
                state.isLoading = false
                return .none

            case .detailLoaded(.failure(let error)):
                state.error = error.localizedDescription
                state.isLoading = false
                return .none

            case .logsLoaded(.success(let logs)):
                state.logs = logs
                return .none

            case .logsLoaded(.failure):
                return .none

            case .resourcesLoaded(.success(let resources)):
                if let resource = resources.first(where: { $0.containerName == state.container.name }) {
                    state.currentResources = resource
                    let snapshot = ResourceSnapshot(
                        timestamp: .now,
                        cpuPercent: resource.cpuPercent,
                        memoryPercent: resource.memoryPercent,
                        networkRx: resource.networkRx,
                        networkTx: resource.networkTx
                    )
                    state.resourceHistory.append(snapshot)
                    if state.resourceHistory.count > 60 {
                        state.resourceHistory.removeFirst()
                    }
                }
                return .none

            case .resourcesLoaded(.failure):
                return .none

            case .actionTapped(let action):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                state.isPerformingAction = true
                state.error = nil
                let name = state.container.name
                return .run { [baseURL, session] send in
                    try await api.performContainerAction(baseURL, session, name, action)
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

            case .startResourcePolling:
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(5)) {
                        await send(.resourcePollTick)
                    }
                }
                .cancellable(id: CancelID.resourcePolling, cancelInFlight: true)

            case .stopResourcePolling:
                return .cancel(id: CancelID.resourcePolling)

            case .resourcePollTick:
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return .run { [baseURL, session] send in
                    let resources = try await api.getContainerResources(baseURL, session)
                    await send(.resourcesLoaded(.success(resources)))
                } catch: { error, send in
                    await send(.resourcesLoaded(.failure(error)))
                }

            case .loadMoreLogs:
                return .none
            }
        }
    }
}
