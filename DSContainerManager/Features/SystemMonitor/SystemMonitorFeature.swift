import ComposableArchitecture
import Foundation
import Tagged

@Reducer
struct SystemMonitorFeature {
    @ObservableState
    struct State: Equatable {
        var baseURL: URL?
        var authSession: AuthSession?
        var currentUtilization: SystemUtilization?
        var storageInfo: StorageInfo?
        var cpuHistory: [ResourceSnapshot] = []
        var memoryHistory: [ResourceSnapshot] = []
        var networkHistory: [ResourceSnapshot] = []
        var isLoading = false
        var error: String?
        var maxHistoryPoints: Int = 60

        var cpuPercent: Double { currentUtilization?.cpu.totalPercent ?? 0 }
        var memoryPercent: Double { currentUtilization?.memory.usagePercent ?? 0 }
    }

    enum Action {
        case onAppear
        case onDisappear
        case refresh
        case startPolling
        case stopPolling
        case pollTick
        case utilizationLoaded(Result<SystemUtilization, Error>)
        case storageLoaded(Result<StorageInfo, Error>)
    }

    private enum CancelID { case polling }

    @Dependency(\.synologyClient) var api
    @Dependency(\.continuousClock) var clock

    nonisolated var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    state.error = "Not connected"
                    return .none
                }
                state.isLoading = state.currentUtilization == nil
                return .merge(
                    fetchUtilization(baseURL: baseURL, session: session),
                    fetchStorage(baseURL: baseURL, session: session),
                    .send(.startPolling)
                )

            case .onDisappear:
                return .cancel(id: CancelID.polling)

            case .refresh:
                state.error = nil
                guard let baseURL = state.baseURL, let session = state.authSession else {
                    return .none
                }
                return .merge(
                    fetchUtilization(baseURL: baseURL, session: session),
                    fetchStorage(baseURL: baseURL, session: session)
                )

            case .startPolling:
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(5)) {
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
                return fetchUtilization(baseURL: baseURL, session: session)

            case .utilizationLoaded(.success(let util)):
                state.isLoading = false
                state.currentUtilization = util
                state.error = nil

                let snapshot = ResourceSnapshot(
                    timestamp: .now,
                    cpuPercent: util.cpu.totalPercent,
                    memoryPercent: util.memory.usagePercent,
                    networkRx: Int64(util.network.first(where: { $0.device == "total" })?.rx ?? 0),
                    networkTx: Int64(util.network.first(where: { $0.device == "total" })?.tx ?? 0)
                )

                state.cpuHistory.append(snapshot)
                state.memoryHistory.append(snapshot)
                state.networkHistory.append(snapshot)

                if state.cpuHistory.count > state.maxHistoryPoints {
                    state.cpuHistory.removeFirst()
                }
                if state.memoryHistory.count > state.maxHistoryPoints {
                    state.memoryHistory.removeFirst()
                }
                if state.networkHistory.count > state.maxHistoryPoints {
                    state.networkHistory.removeFirst()
                }

                return .none

            case .utilizationLoaded(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .storageLoaded(.success(let info)):
                state.storageInfo = info
                return .none

            case .storageLoaded(.failure):
                return .none
            }
        }
    }

    private func fetchUtilization(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            let util = try await api.getSystemUtilization(baseURL, session)
            await send(.utilizationLoaded(.success(util)))
        } catch: { error, send in
            await send(.utilizationLoaded(.failure(error)))
        }
    }

    private func fetchStorage(baseURL: URL, session: AuthSession) -> Effect<Action> {
        .run { send in
            let storage = try await api.getStorageInfo(baseURL, session)
            await send(.storageLoaded(.success(storage)))
        } catch: { error, send in
            await send(.storageLoaded(.failure(error)))
        }
    }
}
