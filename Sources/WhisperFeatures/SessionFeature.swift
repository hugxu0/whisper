import WhisperDomain
import WhisperClients

public struct WhisperSessionState: Equatable, Sendable {
    public var isLoading = false
    public var account: WhisperAccount?
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
            return .login
        case .loginSucceeded:
            return .loadBootstrap
        case .bootstrapSucceeded:
            state.isLoading = false
            return .connectSocket
        case .failed(let message):
            state.isLoading = false
            state.lastError = message
            return nil
        }
    }
}
