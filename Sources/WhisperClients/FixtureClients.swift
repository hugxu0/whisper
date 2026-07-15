import Foundation

/// Deterministic transport for local contract tests and previews. It accepts
/// route-keyed responses instead of reading the live service or legacy code.
public actor WhisperStubHTTPClient: WhisperHTTPClient {
    private let responses: [String: WhisperHTTPResponse]
    private var recordedRequests: [WhisperHTTPRequest] = []

    public init(responses: [String: WhisperHTTPResponse]) {
        self.responses = responses
    }

    public func send(_ request: WhisperHTTPRequest) async throws -> WhisperHTTPResponse {
        recordedRequests.append(request)
        guard let response = responses[request.routeKey] else {
            throw WhisperHTTPClientError.invalidResponse
        }
        return response
    }

    public func requests() -> [WhisperHTTPRequest] {
        recordedRequests
    }
}

public actor WhisperStubSocketClient: WhisperSocketClient {
    private var connectError: WhisperSocketError?
    private var connectedToken: String?
    private let lifecycleStream: AsyncStream<WhisperSocketLifecycleEvent>
    private let lifecycleContinuation: AsyncStream<WhisperSocketLifecycleEvent>.Continuation

    public init(connectError: WhisperSocketError? = nil) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: WhisperSocketLifecycleEvent.self,
            bufferingPolicy: .bufferingNewest(16)
        )
        self.connectError = connectError
        self.lifecycleStream = stream
        self.lifecycleContinuation = continuation
    }

    public func connect(token: String) async throws {
        if let connectError {
            lifecycleContinuation.yield(.failed(String(describing: connectError)))
            throw connectError
        }
        connectedToken = token
        lifecycleContinuation.yield(.connected)
    }

    public func disconnect() async {
        connectedToken = nil
        lifecycleContinuation.yield(.disconnected("fixture disconnect"))
    }

    public func lifecycleEvents() async -> AsyncStream<WhisperSocketLifecycleEvent> {
        lifecycleStream
    }

    public func setConnectError(_ error: WhisperSocketError?) {
        connectError = error
    }

    public func currentToken() -> String? {
        connectedToken
    }
}
