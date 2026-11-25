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
        /// The connection whose sign-in just failed, so Retry signs in again rather than reloading the list.
        var failedConnection: ConnectionProfile?
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
        case retryTapped
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
                state.failedConnection = nil
                state.isLoading = false
                return .none

            case .addButtonTapped:
                state.connectionForm = ConnectionFormFeature.State(
                    mode: .add,
                    name: "",
                    host: "",
                    port: 5000,
                    useHTTPS: false,
                    username: "",
                    password: "",
                    trustSelfSignedCert: false,
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
                    trustSelfSignedCert: profile.trustSelfSignedCert,
                    lastConnected: profile.lastConnected,
                    isDefault: profile.isDefault,
                )
                return .none

            case let .deleteConnection(id):
                return .run { send in
                    try keychain.deletePassword(forConnection: id)
                    try keychain.deleteDeviceToken(forConnection: id)
                    try await store.delete(id)
                    let result = await Result { try await store.fetchAll() }
                    await send(.connectionsLoaded(result))
                }

            case .deleteResult:
                return .none

            case .retryTapped:
                guard let profile = state.failedConnection else {
                    return .send(.loadConnections)
                }
                return .send(.connectTapped(profile))

            case let .connectTapped(profile):
                state.loginInProgressId = profile.id
                state.error = nil
                state.failedConnection = nil
                let password = (try? keychain.loadPassword(forConnection: profile.id)) ?? ""
                let deviceToken = try? keychain.loadDeviceToken(forConnection: profile.id)
                guard let baseURL = profile.baseURL else {
                    state.error = "Invalid URL for \(profile.name)"
                    state.loginInProgressId = nil
                    return .none
                }
                return .run { send in
                    let result = await Result {
                        try await api.login(baseURL, profile.username, password, nil, deviceToken)
                    }
                    await send(.loginResult(result, profile))
                }

            case let .loginResult(.success(session), profile):
                state.loginInProgressId = nil
                return .run { send in
                    if let deviceToken = session.deviceId {
                        try? keychain.saveDeviceToken(deviceToken, forConnection: profile.id)
                    }
                    await send(.delegate(.connectionEstablished(profile, session)))
                }

            case let .loginResult(.failure(error), profile):
                state.loginInProgressId = nil
                if let apiError = error as? SynologyAPIError, apiError == .otpRequired {
                    let password = (try? keychain.loadPassword(forConnection: profile.id)) ?? ""
                    state.otpPrompt = State.OTPPromptState(
                        connectionProfile: profile,
                        password: password,
                    )
                } else {
                    state.error = error.localizedDescription
                    state.failedConnection = profile
                }
                return .none

            case let .connectionForm(.presented(.delegate(.saved(profile, password)))):
                state.connectionForm = nil
                let isNew = !state.connections.contains { $0.id == profile.id }
                return .run { send in
                    try keychain.savePassword(password, forConnection: profile.id)
                    try await store.save(profile)
                    let result = await Result { try await store.fetchAll() }
                    await send(.connectionsLoaded(result))
                    // A new NAS was added to be used: sign in right away instead of making people tap it.
                    if isNew {
                        await send(.connectTapped(profile))
                    }
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
                        try await api.login(baseURL, profile.username, password, otpCode, nil)
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
        var lastConnected: Date?
        var isDefault = false

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
            !trimmedHost.isEmpty && !username.isEmpty && port > 0 && port <= 65535
        }

        private var trimmedHost: String {
            host.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var title: String {
            switch mode {
            case .add: "Add Connection"
            case .edit: "Edit Connection"
            }
        }

        func toProfile() -> ConnectionProfile {
            let id: UUID = switch mode {
            case .add: UUID()
            case let .edit(existingId): existingId
            }
            let address = HostAddress(parsing: host)
            let useHTTPS = address.useHTTPS ?? useHTTPS
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return ConnectionProfile(
                id: id,
                name: trimmedName.isEmpty ? address.host : trimmedName,
                host: address.host,
                port: address.port ?? port,
                useHTTPS: useHTTPS,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                lastConnected: lastConnected,
                isDefault: isDefault,
                trustSelfSignedCert: useHTTPS && trustSelfSignedCert,
            )
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case hostEditingEnded
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
            case .binding(\.useHTTPS):
                // Follow DSM's defaults (5000 for HTTP, 5001 for HTTPS) unless a custom port was set.
                if state.useHTTPS, state.port == 5000 {
                    state.port = 5001
                } else if !state.useHTTPS, state.port == 5001 {
                    state.port = 5000
                }
                return .none
            case .binding:
                return .none
            case .hostEditingEnded:
                // A pasted DSM address ("https://nas.local:5001/") is split into its fields, visibly.
                let address = HostAddress(parsing: state.host)
                state.host = address.host
                if let port = address.port {
                    state.port = port
                }
                if let useHTTPS = address.useHTTPS {
                    state.useHTTPS = useHTTPS
                }
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

// MARK: - Host Address Parsing

/// Accepts a bare host ("192.168.1.10") as well as what people paste from the DSM
/// address bar ("https://nas.local:5001/"), so the scheme and port end up in their own fields.
struct HostAddress: Equatable {
    var host: String
    var port: Int?
    var useHTTPS: Bool?

    init(parsing input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasScheme = trimmed.contains("://")
        // Bracket-less IPv6 literals can't carry a port; leave them untouched.
        let looksLikeIPv6 = !hasScheme && trimmed.filter { $0 == ":" }.count > 1
        guard !trimmed.isEmpty, !looksLikeIPv6,
              let components = URLComponents(string: hasScheme ? trimmed : "placeholder://\(trimmed)"),
              let parsedHost = components.host, !parsedHost.isEmpty
        else {
            host = trimmed
            return
        }
        host = parsedHost
        port = components.port
        switch components.scheme?.lowercased() {
        case "https": useHTTPS = true
        case "http": useHTTPS = false
        default: useHTTPS = nil
        }
    }
}
