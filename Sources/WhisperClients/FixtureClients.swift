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

    public init(connectError: WhisperSocketError? = nil) {
        self.connectError = connectError
    }

    public func connect(token: String) async throws {
        if let connectError { throw connectError }
        connectedToken = token
    }

    public func disconnect() async {
        connectedToken = nil
    }

    public func setConnectError(_ error: WhisperSocketError?) {
        connectError = error
    }

    public func currentToken() -> String? {
        connectedToken
    }
}
