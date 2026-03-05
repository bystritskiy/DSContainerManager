import ComposableArchitecture
import Foundation
import Tagged

@Reducer
struct ContainerListFeature {
    @ObservableState
    struct State: Equatable {
        var baseURL: URL?
        var authSession: AuthSession?
        var containers: [DockerContainer] = []
        var searchText: String = ""
        var statusFilter: ContainerStatus?
        var sortOrder: SortOrder = .name
        var isLoading = false
        var error: String?
        @Presents var detail: ContainerDetailFeature.State?

        enum SortOrder: String, CaseIterable, Sendable {
            case name = "Name"
            case status = "Status"
            case created = "Created"
        }

        var filteredContainers: [DockerContainer] {
            var result = containers
            if let filter = statusFilter {
                result = result.filter { $0.status == filter }
            }
            if !searchText.isEmpty {
                result = result.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.image.localizedCaseInsensitiveContains(searchText)
                }
            }
            switch sortOrder {
            case .name:
                result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .status:
                result.sort { $0.status.rawValue < $1.status.rawValue }
            case .created:
                result.sort { $0.created > $1.created }
            }
            return result
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case refresh
        case containersLoaded(Result<[DockerContainer], Error>)
        case containerTapped(DockerContainer)
        case swipeAction(DockerContainer, ContainerAction)
        case actionResult(Result<Void, Error>)
        case detail(PresentationAction<ContainerDetailFeature.Action>)
        case statusFilterChanged(ContainerStatus?)
        case sortOrderChanged(State.SortOrder)
    }

    private enum CancelID { case polling }

    @Dependency(\.synologyClient) var api
    @Dependency(\.continuousClock) var clock

    nonisolated var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                guard !state.isLoading else { return .none }
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    state.error = "Not connected"
                    return .none
                }
                state.isLoading = state.containers.isEmpty
                return .merge(
                    fetchContainers(baseURL: baseURL, session: session),
                    startPolling()
                )

            case .refresh:
                state.error = nil
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return fetchContainers(baseURL: baseURL, session: session)

            case .containersLoaded(.success(let containers)):
                state.isLoading = false
                state.containers = containers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                state.error = nil
                return .none

            case .containersLoaded(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .containerTapped(let container):
                var detailState = ContainerDetailFeature.State(container: container)
                detailState.baseURL = state.baseURL
                detailState.authSession = state.authSession
                state.detail = detailState
                return .none

            case .swipeAction(let container, let action):
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return .run { send in
                    try await api.performContainerAction(baseURL, session, container.name, action)
                    // Refresh the list after action
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

            case .statusFilterChanged(let filter):
                state.statusFilter = filter
                return .none

            case .sortOrderChanged(let order):
                state.sortOrder = order
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            ContainerDetailFeature()
        }
    }

    private func fetchContainers(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            let containers = try await api.listContainers(baseURL, session)
            await send(.containersLoaded(.success(containers)))
        } catch: { error, send in
            await send(.containersLoaded(.failure(error)))
        }
    }

    private func startPolling() -> Effect<Action> {
        .run { send in
            for await _ in clock.timer(interval: .seconds(10)) {
                await send(.refresh)
            }
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }
}
