import Foundation
import WhisperDomain

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

public actor WhisperStubSocketClient: WhisperSocketMessagingClient {
    private var connectError: WhisperSocketError?
    private var connectedToken: String?
    private var acknowledgement: WhisperMessageSendAck?
    private var sendError: WhisperSocketError?
    private var sentMessages: [WhisperMessageSend] = []
    private let eventStream: AsyncStream<WhisperSocketEventEnvelope>
    private let eventContinuation: AsyncStream<WhisperSocketEventEnvelope>.Continuation
    private let lifecycleStream: AsyncStream<WhisperSocketLifecycleEvent>
    private let lifecycleContinuation: AsyncStream<WhisperSocketLifecycleEvent>.Continuation

    public init(
        connectError: WhisperSocketError? = nil,
        acknowledgement: WhisperMessageSendAck? = nil,
        sendError: WhisperSocketError? = nil
    ) {
        let (eventStream, eventContinuation) = AsyncStream.makeStream(
            of: WhisperSocketEventEnvelope.self,
            bufferingPolicy: .bufferingNewest(64)
        )
        let (stream, continuation) = AsyncStream.makeStream(
            of: WhisperSocketLifecycleEvent.self,
            bufferingPolicy: .bufferingNewest(16)
        )
        self.connectError = connectError
        self.acknowledgement = acknowledgement
        self.sendError = sendError
        self.eventStream = eventStream
        self.eventContinuation = eventContinuation
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

    public func events() async -> AsyncStream<WhisperSocketEventEnvelope> {
        eventStream
    }

    public func sendMessage(_ message: WhisperMessageSend) async throws -> WhisperMessageSendAck {
        sentMessages.append(message)
        if let sendError {
            throw sendError
        }
        guard let acknowledgement else {
            throw WhisperSocketError.acknowledgementFailed("fixture acknowledgement missing")
        }
        return acknowledgement
    }

    public func setConnectError(_ error: WhisperSocketError?) {
        connectError = error
    }

    public func currentToken() -> String? {
        connectedToken
    }

    public func sentMessageRequests() -> [WhisperMessageSend] {
        sentMessages
    }

    public func emit(_ event: WhisperSocketEventEnvelope) {
        eventContinuation.yield(event)
    }

    public func finishEvents() {
        eventContinuation.finish()
    }

    public func setAcknowledgement(_ acknowledgement: WhisperMessageSendAck?) {
        self.acknowledgement = acknowledgement
    }

    public func setSendError(_ error: WhisperSocketError?) {
        sendError = error
    }
}
