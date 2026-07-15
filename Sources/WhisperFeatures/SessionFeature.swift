import Observation
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
@Observable
public final class WhisperSessionController {
    public private(set) var state: WhisperSessionState

    private let api: any WhisperSessionAPI
    private let socket: any WhisperSocketClient
    @ObservationIgnored
    private var attempt = 0
    @ObservationIgnored
    private var sessionToken: String?

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
        sessionToken = nil
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
            sessionToken = login.token
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

    public func reconnect() async {
        guard let sessionToken else { return }

        attempt &+= 1
        let currentAttempt = attempt
        state.isLoading = true
        state.lastError = nil
        state.connection = .connecting

        do {
            try await socket.connect(token: sessionToken)
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

    public func monitorConnection() async {
        let events = await socket.lifecycleEvents()
        for await event in events {
            guard Task.isCancelled == false else { return }
            switch event {
            case .connected:
                state.connection = .connected
                state.lastError = nil
            case .reconnecting:
                state.connection = .connecting
            case .disconnected:
                state.connection = .idle
            case .failed(let message):
                state.connection = .failed(message)
                state.lastError = message
            }
        }
    }

    public func stop() async {
        attempt &+= 1
        sessionToken = nil
        await socket.disconnect()
        state.isLoading = false
        state.connection = .idle
    }

    private func ensureCurrent(_ currentAttempt: Int) throws {
        guard currentAttempt == attempt else { throw CancellationError() }
    }
}
