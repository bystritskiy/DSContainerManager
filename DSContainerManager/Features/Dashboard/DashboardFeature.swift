import ComposableArchitecture
import Foundation

@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        var baseURL: URL?
        var authSession: AuthSession?
        var nasName: String?
        var systemUtilization: SystemUtilization?
        var storageInfo: StorageInfo?
        var containers: [DockerContainer] = []
        var isLoading = false
        var error: String?

        var runningCount: Int {
            containers.count(where: { $0.status == .running })
        }

        var stoppedCount: Int {
            containers.count(where: { $0.status == .stopped })
        }

        var totalCount: Int {
            containers.count
        }

        /// A short preview for the dashboard card; the Containers tab has the full list.
        var runningPreview: [DockerContainer] {
            Array(containers.filter { $0.status == .running }.prefix(5))
        }

        var cpuPercent: Double {
            systemUtilization?.cpu.totalPercent ?? 0
        }

        var memoryPercent: Double {
            systemUtilization?.memory.usagePercent ?? 0
        }
    }

    enum Action {
        case onAppear
        case refresh
        case dataLoaded(Result<DashboardData, Error>)
        case startPolling
        case stopPolling
        case pollTick
        case showAllContainersTapped
        case containerCountTapped(ContainerStatus?)
        case containerTapped(DockerContainer)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case showAllContainers
            case showContainers(ContainerStatus?)
            case showContainer(DockerContainer)
        }
    }

    /// `nil` fields failed to load; the previous values stay on screen for those.
    struct DashboardData: Equatable {
        var utilization: SystemUtilization?
        var containers: [DockerContainer]?
        var storage: StorageInfo?
    }

    enum CancelID { case load, polling }

    @Dependency(\.synologyClient) var api
    @Dependency(\.continuousClock) var clock

    nonisolated var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    state.error = "Not connected"
                    return .none
                }
                state.isLoading = state.systemUtilization == nil
                return .merge(
                    fetchData(baseURL: baseURL, session: session),
                    .send(.startPolling),
                )

            case .refresh:
                state.error = nil
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return fetchData(baseURL: baseURL, session: session)

            case let .dataLoaded(.success(data)):
                state.isLoading = false
                if let util = data.utilization {
                    state.systemUtilization = util
                }
                if let containers = data.containers {
                    state.containers = containers
                }
                if let storage = data.storage {
                    state.storageInfo = storage
                }
                state.error = nil
                return .none

            case let .dataLoaded(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .startPolling:
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(10)) {
                        await send(.pollTick)
                    }
                }
                .cancellable(id: CancelID.polling, cancelInFlight: true)

            case .stopPolling:
                return .cancel(id: CancelID.polling)

            case .pollTick:
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return fetchData(baseURL: baseURL, session: session)

            case .showAllContainersTapped:
                return .send(.delegate(.showAllContainers))

            case let .containerCountTapped(status):
                return .send(.delegate(.showContainers(status)))

            case let .containerTapped(container):
                return .send(.delegate(.showContainer(container)))

            case .delegate:
                return .none
            }
        }
    }

    private func fetchData(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            // Fetch each independently so one failure doesn't block others
            async let utilization = Result { try await api.getSystemUtilization(baseURL, session) }
            async let containers = Result { try await api.listContainers(baseURL, session) }
            async let storage = Result { try await api.getStorageInfo(baseURL, session) }
            let results = await (utilization, containers, storage)

            let dashData = DashboardData(
                utilization: try? results.0.get(),
                containers: try? results.1.get(),
                storage: try? results.2.get(),
            )

            #if DEBUG
                let outcomes = [results.0.map { _ in () }, results.1.map { _ in () }, results.2.map { _ in () }]
                for case let .failure(error) in outcomes {
                    print("[Dashboard] Failed to load: \(error)")
                }
            #endif

            // Nothing came back (NAS offline, session gone): report it instead of showing stale numbers.
            let nothingLoaded = dashData.utilization == nil && dashData.containers == nil && dashData.storage == nil
            if nothingLoaded, case let .failure(error) = results.0 {
                await send(.dataLoaded(.failure(error)))
            } else {
                await send(.dataLoaded(.success(dashData)))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }
}
