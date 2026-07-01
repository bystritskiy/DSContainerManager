import ComposableArchitecture
import Foundation
import Tagged

enum ContainerDetailTab: String, CaseIterable {
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
        var container: DockerContainer
        var baseURL: URL?
        var authSession: AuthSession?

        init(container: DockerContainer, detail: ContainerDetail? = nil) {
            id = container.id.rawValue
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
        case refreshDetail
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
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case containerUpdated(DockerContainer)
    }

    enum CancelID { case detail, logs, resources, action, resourcePolling }

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
                    fetchDetail(baseURL: baseURL, session: session, name: name),
                    fetchLogs(baseURL: baseURL, session: session, name: name),
                    .send(.startResourcePolling),
                )

            case .refreshDetail:
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return fetchDetail(baseURL: baseURL, session: session, name: state.container.name)

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .detailLoaded(.success(detail)):
                state.detail = detail
                let container = updatedContainer(from: detail, keeping: state.container)
                state.container = container
                state.isLoading = false
                state.isPerformingAction = false
                return .send(.delegate(.containerUpdated(container)))

            case let .detailLoaded(.failure(error)):
                state.error = error.localizedDescription
                state.isLoading = false
                state.isPerformingAction = false
                return .none

            case let .logsLoaded(.success(logs)):
                state.logs = logs
                return .none

            case let .logsLoaded(.failure(error)):
                state.error = "Failed to load logs: \(error.localizedDescription)"
                #if DEBUG
                    print("[ContainerDetailFeature] Failed to load logs for \(state.container.name): \(error.localizedDescription)")
                #endif
                return .none

            case let .resourcesLoaded(.success(resources)):
                if let resource = resources.first(where: { $0.containerName == state.container.name }) {
                    state.currentResources = resource
                    let snapshot = ResourceSnapshot(
                        timestamp: .now,
                        cpuPercent: resource.cpuPercent,
                        memoryPercent: resource.memoryPercent,
                        networkRx: resource.networkRx,
                        networkTx: resource.networkTx,
                    )
                    state.resourceHistory.append(snapshot)
                    if state.resourceHistory.count > 60 {
                        state.resourceHistory.removeFirst()
                    }
                }
                return .none

            case .resourcesLoaded(.failure):
                return .none

            case let .actionTapped(action):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                state.isPerformingAction = true
                state.error = nil
                let name = state.container.name
                return .run { [baseURL, session] send in
                    try await api.performContainerAction(baseURL, session, name, action)
                    await send(.refreshDetail)
                } catch: { error, send in
                    await send(.actionResult(.failure(error)))
                }
                .cancellable(id: CancelID.action, cancelInFlight: true)

            case .actionResult(.success):
                state.isPerformingAction = false
                return .none

            case let .actionResult(.failure(error)):
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
                return fetchResources(baseURL: baseURL, session: session)

            case .loadMoreLogs:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func fetchDetail(baseURL: URL, session: AuthSession, name: String) -> Effect<Action> {
        .run { send in
            let detail = try await api.getContainerDetail(baseURL, session, name)
            await send(.detailLoaded(.success(detail)))
        } catch: { error, send in
            await send(.detailLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.detail, cancelInFlight: true)
    }

    private func fetchLogs(baseURL: URL, session: AuthSession, name: String) -> Effect<Action> {
        .run { send in
            let logs = try await api.getContainerLogs(baseURL, session, name, 0, 100)
            await send(.logsLoaded(.success(logs)))
        } catch: { error, send in
            await send(.logsLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.logs, cancelInFlight: true)
    }

    private func fetchResources(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            let resources = try await api.getContainerResources(baseURL, session)
            await send(.resourcesLoaded(.success(resources)))
        } catch: { error, send in
            await send(.resourcesLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.resources, cancelInFlight: true)
    }

    private func updatedContainer(from detail: ContainerDetail, keeping container: DockerContainer) -> DockerContainer {
        DockerContainer(
            id: container.id,
            name: detail.name,
            image: detail.image,
            status: detail.status,
            state: detail.status.rawValue,
            created: detail.created,
            ports: detail.ports,
            isPackage: container.isPackage,
        )
    }
}
