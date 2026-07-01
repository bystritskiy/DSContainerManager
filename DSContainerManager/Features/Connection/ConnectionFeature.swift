import ComposableArchitecture
import Foundation

@Reducer
struct ConnectionFeature {
    @ObservableState
    struct State: Equatable {
        var connections: [ConnectionProfile] = []
        var isLoading = false
        var error: String?
        var loginInProgressId: UUID?
        @Presents var connectionForm: ConnectionFormFeature.State?
        var otpPrompt: OTPPromptState?

        struct OTPPromptState: Equatable {
            var otpCode: String = ""
            let connectionProfile: ConnectionProfile
            let password: String
        }
    }

    enum Action {
        case loadConnections
        case connectionsLoaded(Result<[ConnectionProfile], Error>)
        case addButtonTapped
        case editButtonTapped(ConnectionProfile)
        case deleteConnection(UUID)
        case deleteResult(Result<Void, Error>)
        case connectTapped(ConnectionProfile)
        case loginResult(Result<AuthSession, Error>, ConnectionProfile)
        case connectionForm(PresentationAction<ConnectionFormFeature.Action>)
        case dismissOTPPrompt
        case otpSubmitted(String, ConnectionProfile, String)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case connectionEstablished(ConnectionProfile, AuthSession)
        }
    }

    @Dependency(\.synologyClient) var api
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.connectionStore) var store

    nonisolated var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadConnections:
                state.isLoading = true
                state.error = nil
                return .run { send in
                    let result = await Result { try await store.fetchAll() }
                    await send(.connectionsLoaded(result))
                }

            case let .connectionsLoaded(.success(profiles)):
                state.connections = profiles
                state.isLoading = false
                return .none

            case let .connectionsLoaded(.failure(error)):
                state.error = error.localizedDescription
                state.isLoading = false
                return .none

            case .addButtonTapped:
                state.connectionForm = ConnectionFormFeature.State(
                    mode: .add,
                    name: "",
                    host: "",
                    port: 5000,
                    useHTTPS: false,
                    username: "admin",
                    password: "",
                    trustSelfSignedCert: false
                )
                return .none

            case let .editButtonTapped(profile):
                let password = (try? keychain.loadPassword(forConnection: profile.id)) ?? ""
                state.connectionForm = ConnectionFormFeature.State(
                    mode: .edit(profile.id),
                    name: profile.name,
                    host: profile.host,
                    port: profile.port,
                    useHTTPS: profile.useHTTPS,
                    username: profile.username,
                    password: password,
                    trustSelfSignedCert: profile.trustSelfSignedCert
                )
                return .none

            case let .deleteConnection(id):
                return .run { send in
                    try keychain.deletePassword(forConnection: id)
                    try await store.delete(id)
                    let result = await Result { try await store.fetchAll() }
                    await send(.connectionsLoaded(result))
                }

            case .deleteResult:
                return .none

            case let .connectTapped(profile):
                state.loginInProgressId = profile.id
                state.error = nil
                let password = (try? keychain.loadPassword(forConnection: profile.id)) ?? ""
                guard let baseURL = profile.baseURL else {
                    state.error = "Invalid URL for \(profile.name)"
                    state.loginInProgressId = nil
                    return .none
                }
                return .run { send in
                    let result = await Result {
                        try await api.login(baseURL, profile.username, password, nil)
                    }
                    await send(.loginResult(result, profile))
                }

            case let .loginResult(.success(session), profile):
                state.loginInProgressId = nil
                return .send(.delegate(.connectionEstablished(profile, session)))

            case let .loginResult(.failure(error), profile):
                state.loginInProgressId = nil
                if let apiError = error as? SynologyAPIError, apiError == .otpRequired {
                    let password = (try? keychain.loadPassword(forConnection: profile.id)) ?? ""
                    state.otpPrompt = State.OTPPromptState(
                        connectionProfile: profile,
                        password: password
                    )
                } else {
                    state.error = error.localizedDescription
                }
                return .none

            case let .connectionForm(.presented(.delegate(.saved(profile, password)))):
                state.connectionForm = nil
                return .run { send in
                    try keychain.savePassword(password, forConnection: profile.id)
                    try await store.save(profile)
                    let result = await Result { try await store.fetchAll() }
                    await send(.connectionsLoaded(result))
                }

            case .connectionForm(.presented(.delegate(.cancelled))):
                state.connectionForm = nil
                return .none

            case .connectionForm:
                return .none

            case let .otpSubmitted(otpCode, profile, password):
                state.otpPrompt = nil
                state.loginInProgressId = profile.id
                guard let baseURL = profile.baseURL else {
                    state.error = "Invalid URL"
                    state.loginInProgressId = nil
                    return .none
                }
                return .run { send in
                    let result = await Result {
                        try await api.login(baseURL, profile.username, password, otpCode)
                    }
                    await send(.loginResult(result, profile))
                }

            case .dismissOTPPrompt:
                state.otpPrompt = nil
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$connectionForm, action: \.connectionForm) {
            ConnectionFormFeature()
        }
    }
}

// MARK: - Connection Form Feature

@Reducer
struct ConnectionFormFeature {
    @ObservableState
    struct State: Equatable {
        var mode: Mode
        var name: String
        var host: String
        var port: Int
        var useHTTPS: Bool
        var username: String
        var password: String
        var trustSelfSignedCert: Bool

        enum Mode: Equatable {
            case add
            case edit(UUID)

            var id: UUID {
                switch self {
                case .add: UUID()
                case let .edit(id): id
                }
            }
        }

        var isValid: Bool {
            !name.isEmpty && !host.isEmpty && !username.isEmpty && port > 0 && port <= 65535
        }

        var title: String {
            switch mode {
            case .add: "Add Connection"
            case .edit: "Edit Connection"
            }
        }

        func toProfile() -> ConnectionProfile {
            let id: UUID = {
                switch mode {
                case .add: UUID()
                case let .edit(existingId): existingId
                }
            }()
            return ConnectionProfile(
                id: id,
                name: name,
                host: host,
                port: port,
                useHTTPS: useHTTPS,
                username: username,
                lastConnected: nil,
                isDefault: false,
                trustSelfSignedCert: trustSelfSignedCert
            )
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case saved(ConnectionProfile, String)
            case cancelled
        }
    }

    nonisolated var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .saveButtonTapped:
                let profile = state.toProfile()
                let password = state.password
                return .send(.delegate(.saved(profile, password)))
            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))
            case .delegate:
                return .none
            }
        }
    }
}
