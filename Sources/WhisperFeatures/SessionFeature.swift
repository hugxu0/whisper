import WhisperDomain
import WhisperClients

public enum WhisperConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case failed(String)
}

public struct WhisperSessionState: Equatable, Sendable {
    public var isLoading = false
    public var account: WhisperAccount?
    public var bootstrap: WhisperBootstrapResponse?
    public var connection: WhisperConnectionState = .idle
    public var lastError: String?

    public init() {}
}

public enum WhisperSessionAction: Equatable, Sendable {
    case launch
    case loginSucceeded(WhisperLoginResponse)
    case bootstrapSucceeded(WhisperBootstrapResponse)
    case failed(String)
}

public enum WhisperSessionEffect: Equatable, Sendable {
    case login
    case loadBootstrap
    case connectSocket
}

/// The first feature boundary is deliberately only a state/action/effect
/// contract. Side effects will be supplied by injected clients in the first
/// vertical slice; no global store or legacy adapter is introduced here.
public enum WhisperSessionFeature {
    public static func reduce(
        state: inout WhisperSessionState,
        action: WhisperSessionAction
    ) -> WhisperSessionEffect? {
        switch action {
        case .launch:
            state.isLoading = true
            state.lastError = nil
            state.connection = .connecting
            return .login
        case .loginSucceeded(let login):
            state.account = WhisperAccount(username: login.username, name: login.name)
            return .loadBootstrap
        case .bootstrapSucceeded(let bootstrap):
            state.bootstrap = bootstrap
            state.isLoading = false
            return .connectSocket
        case .failed(let message):
            state.isLoading = false
            state.lastError = message
            state.connection = .failed(message)
            return nil
        }
    }
}

/// Main-actor orchestration for the first vertical slice. SwiftUI can own this
/// object with `@State` and call `start` from a `.task`, which gives cancellation
/// to the view lifecycle without a long-lived unstructured task in the feature.
@MainActor
public final class WhisperSessionController {
    public private(set) var state: WhisperSessionState

    private let api: any WhisperSessionAPI
    private let socket: any WhisperSocketClient
    private var attempt = 0

    public init(
        api: any WhisperSessionAPI,
        socket: any WhisperSocketClient,
        state: WhisperSessionState = WhisperSessionState()
    ) {
        self.api = api
        self.socket = socket
        self.state = state
    }

    public func start(request: WhisperLoginRequest) async {
        attempt &+= 1
        let currentAttempt = attempt
        state.isLoading = true
        state.lastError = nil
        state.connection = .connecting

        do {
            let login = try await api.login(request)
            try ensureCurrent(currentAttempt)
            try Task.checkCancellation()

            state.account = WhisperAccount(
                username: login.username,
                name: login.name
            )
            state.bootstrap = try await api.bootstrap()
            try ensureCurrent(currentAttempt)
            try Task.checkCancellation()

            state.connection = .connecting
            try await socket.connect(token: login.token)
            try ensureCurrent(currentAttempt)
            try Task.checkCancellation()
            state.isLoading = false
            state.connection = .connected
        } catch is CancellationError {
            guard currentAttempt == attempt else { return }
            state.isLoading = false
            state.connection = .idle
        } catch {
            guard currentAttempt == attempt else { return }
            state.isLoading = false
            state.lastError = String(describing: error)
            state.connection = .failed(String(describing: error))
        }
    }

    public func retry(request: WhisperLoginRequest) async {
        await start(request: request)
    }

    public func stop() async {
        attempt &+= 1
        await socket.disconnect()
        state.isLoading = false
        state.connection = .idle
    }

    private func ensureCurrent(_ currentAttempt: Int) throws {
        guard currentAttempt == attempt else { throw CancellationError() }
    }
}
