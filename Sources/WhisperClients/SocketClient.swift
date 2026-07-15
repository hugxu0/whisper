public enum WhisperSocketError: Error, Equatable, Sendable {
    case connectionFailed(String)
}

public protocol WhisperSocketClient: Sendable {
    func connect(token: String) async throws
    func disconnect() async
}

/// Socket.IO wiring will be added behind this boundary. The first slice only
/// needs lifecycle ownership; message streams and ack routing come next.
public actor WhisperSocketLifecycleClient: WhisperSocketClient {
    public init() {}

    public func connect(token: String) async throws {
        // Intentionally empty until the Socket.IO dependency is selected.
        _ = token
    }

    public func disconnect() async {}
}
