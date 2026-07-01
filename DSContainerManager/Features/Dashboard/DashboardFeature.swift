import ComposableArchitecture
import Foundation
import Tagged

@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        var baseURL: URL?
        var authSession: AuthSession?
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
    }

    struct DashboardData: Equatable {
        var utilization: SystemUtilization?
        var containers: [DockerContainer] = []
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
                state.containers = data.containers
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
            }
        }
    }

    private func fetchData(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            var dashData = DashboardData()

            // Fetch each independently so one failure doesn't block others
            do {
                dashData.utilization = try await api.getSystemUtilization(baseURL, session)
            } catch {
                print("[Dashboard] Failed to load utilization: \(error)")
            }

            do {
                dashData.containers = try await api.listContainers(baseURL, session)
            } catch {
                print("[Dashboard] Failed to load containers: \(error)")
            }

            do {
                dashData.storage = try await api.getStorageInfo(baseURL, session)
            } catch {
                print("[Dashboard] Failed to load storage: \(error)")
            }

            await send(.dataLoaded(.success(dashData)))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }
}
