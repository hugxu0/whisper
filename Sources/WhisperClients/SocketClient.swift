import WhisperDomain

public enum WhisperSocketError: Error, Equatable, Sendable {
    case connectionFailed(String)
    case connectionTimedOut
    case invalidPayload
    case acknowledgementFailed(String)
    case acknowledgementTimedOut
}

public enum WhisperSocketLifecycleEvent: Equatable, Sendable {
    case connected
    case reconnecting
    case disconnected(String)
    case failed(String)
}

public protocol WhisperSocketClient: Sendable {
    func connect(token: String) async throws
    func disconnect() async
    func lifecycleEvents() async -> AsyncStream<WhisperSocketLifecycleEvent>
}

public struct WhisperSocketAuthentication: Equatable, Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }

    /// Socket.IO CONNECT payload. The retained server deliberately rejects a
    /// query-string token to keep credentials out of proxy access logs.
    public var payload: [String: String] {
        ["token": token]
    }
}

public struct WhisperSocketEventEnvelope: Codable, Equatable, Sendable {
    public let name: String
    public let arguments: [WhisperJSONValue]

    public init(name: String, arguments: [WhisperJSONValue]) {
        self.name = name
        self.arguments = arguments
    }
}

public protocol WhisperSocketMessagingClient: WhisperSocketClient {
    func events() async -> AsyncStream<WhisperSocketEventEnvelope>
    func sendMessage(_ message: WhisperMessageSend) async throws -> WhisperMessageSendAck
    func recallMessage(id: String) async throws -> WhisperRecallAcknowledgement
    func searchMessages(
        channel: WhisperChannel,
        query: String,
        limit: Int
    ) async throws -> WhisperSearchAcknowledgement
    func markRead(channel: WhisperChannel, timestamp: Int64) async throws
}
