import Foundation
import Dispatch
import WhisperClients
import WhisperDomain
@preconcurrency import SocketIO

/// Socket.IO v4 adapter for the retained realtime contract.
///
/// The upstream client is callback-based and requires every interaction to use
/// its serial `handleQueue`. `@unchecked Sendable` is limited to that bridge:
/// all mutable manager/socket state is private, every access runs on the single
/// serial queue, no SDK reference escapes, and no queue block suspends.
public final class WhisperSocketIOClient: @unchecked Sendable, WhisperSocketMessagingClient {
    private let baseURL: URL
    private let loggingEnabled: Bool
    private let handleQueue: DispatchQueue
    private let eventStream: AsyncStream<WhisperSocketEventEnvelope>
    private let eventContinuation: AsyncStream<WhisperSocketEventEnvelope>.Continuation
    private let lifecycleStream: AsyncStream<WhisperSocketLifecycleEvent>
    private let lifecycleContinuation: AsyncStream<WhisperSocketLifecycleEvent>.Continuation

    // Queue-confined state. Access only from `handleQueue`.
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    public init(baseURL: URL, loggingEnabled: Bool = false) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: WhisperSocketEventEnvelope.self,
            bufferingPolicy: .bufferingNewest(256)
        )
        let (lifecycleStream, lifecycleContinuation) = AsyncStream.makeStream(
            of: WhisperSocketLifecycleEvent.self,
            bufferingPolicy: .bufferingNewest(16)
        )
        self.baseURL = baseURL
        self.loggingEnabled = loggingEnabled
        self.handleQueue = DispatchQueue(label: "com.whisper.socketio.handle")
        self.eventStream = stream
        self.eventContinuation = continuation
        self.lifecycleStream = lifecycleStream
        self.lifecycleContinuation = lifecycleContinuation
    }

    public func connect(token: String) async throws {
        let auth = WhisperSocketAuthentication(token: token)
        let connection = AsyncThrowingStream<Void, Error> { continuation in
            handleQueue.async { [self] in
                tearDownLocked()

                let manager = SocketManager(
                    socketURL: baseURL,
                    config: [
                        .handleQueue(handleQueue),
                        .forceNew(true),
                        .reconnects(false),
                        .version(.three),
                        .log(loggingEnabled)
                    ]
                )
                let socket = manager.defaultSocket
                self.manager = manager
                self.socket = socket

                let eventContinuation = self.eventContinuation
                let lifecycleContinuation = self.lifecycleContinuation
                socket.onAny { [eventContinuation] event in
                    let arguments = Self.decodeArguments(event.items ?? [])
                    eventContinuation.yield(
                        WhisperSocketEventEnvelope(name: event.event, arguments: arguments)
                    )
                }

                let connectHandler = socket.once(clientEvent: .connect) { _, _ in
                    lifecycleContinuation.yield(.connected)
                    continuation.yield(())
                    continuation.finish()
                }
                let errorHandler = socket.once(clientEvent: .error) { data, _ in
                    let message = Self.describe(data)
                    lifecycleContinuation.yield(.failed(message))
                    continuation.finish(
                        throwing: WhisperSocketError.connectionFailed(message)
                    )
                }
                socket.on(clientEvent: .disconnect) { data, _ in
                    lifecycleContinuation.yield(.disconnected(Self.describe(data)))
                }
                socket.on(clientEvent: .reconnect) { _, _ in
                    lifecycleContinuation.yield(.reconnecting)
                }

                continuation.onTermination = { @Sendable [self] _ in
                    handleQueue.async { [self] in
                        self.socket?.off(id: connectHandler)
                        self.socket?.off(id: errorHandler)
                    }
                }

                // This is Socket.IO CONNECT auth payload, not query parameters.
                socket.connect(
                    withPayload: auth.payload,
                    timeoutAfter: 15
                ) {
                    continuation.finish(throwing: WhisperSocketError.connectionTimedOut)
                }
            }
        }

        do {
            for try await _ in connection {
                return
            }
            if Task.isCancelled {
                throw CancellationError()
            }
            throw WhisperSocketError.connectionFailed("connection ended before connect")
        } catch {
            await disconnect()
            throw error
        }
    }

    public func disconnect() async {
        await withCheckedContinuation { continuation in
            handleQueue.async { [self] in
                tearDownLocked()
                continuation.resume()
            }
        }
    }

    public func events() async -> AsyncStream<WhisperSocketEventEnvelope> {
        eventStream
    }

    public func lifecycleEvents() async -> AsyncStream<WhisperSocketLifecycleEvent> {
        lifecycleStream
    }

    public func sendMessage(_ message: WhisperMessageSend) async throws -> WhisperMessageSendAck {
        let payload = try Self.encodeObject(message)
        return try await emitWithAcknowledgement(
            event: .messageSend,
            payload: payload,
            response: WhisperMessageSendAck.self
        )
    }

    public func recallMessage(id: String) async throws -> WhisperRecallAcknowledgement {
        try await emitWithAcknowledgement(
            event: .messageRecall,
            payload: ["id": id],
            response: WhisperRecallAcknowledgement.self
        )
    }

    public func searchMessages(
        channel: WhisperChannel,
        query: String,
        limit: Int
    ) async throws -> WhisperSearchAcknowledgement {
        try await emitWithAcknowledgement(
            event: .messagesSearch,
            payload: [
                "channel": channel.rawValue,
                "query": query,
                "limit": min(max(limit, 1), 100)
            ],
            response: WhisperSearchAcknowledgement.self
        )
    }

    public func markRead(channel: WhisperChannel, timestamp: Int64) async throws {
        try await withCheckedThrowingContinuation { continuation in
            handleQueue.async { [self] in
                guard let socket else {
                    continuation.resume(
                        throwing: WhisperSocketError.connectionFailed(
                            "read receipt requires a connected socket"
                        )
                    )
                    return
                }
                socket.emit(
                    WhisperSocketEvent.read.rawValue,
                    ["channel": channel.rawValue, "ts": timestamp]
                )
                continuation.resume()
            }
        }
    }

    private func emitWithAcknowledgement<Response: Decodable & Sendable>(
        event: WhisperSocketEvent,
        payload: [String: Any],
        response: Response.Type
    ) async throws -> Response {
        let acknowledgements = AsyncThrowingStream<Response, Error> { continuation in
            handleQueue.async { [self] in
                guard let socket else {
                    continuation.finish(
                        throwing: WhisperSocketError.connectionFailed(
                            "\(event.rawValue) requires a connected socket"
                        )
                    )
                    return
                }

                socket
                    .emitWithAck(event.rawValue, payload)
                    .timingOut(after: 15) { data in
                        if let status = data.first as? String,
                           status == SocketAckStatus.noAck {
                            continuation.finish(throwing: WhisperSocketError.acknowledgementTimedOut)
                            return
                        }

                        do {
                            let acknowledgement = try Self.decodeAcknowledgement(
                                data,
                                as: response
                            )
                            continuation.yield(acknowledgement)
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
            }
        }

        for try await acknowledgement in acknowledgements {
            return acknowledgement
        }
        if Task.isCancelled { throw CancellationError() }
        throw WhisperSocketError.acknowledgementFailed("ack stream ended without a value")
    }

    private func tearDownLocked() {
        dispatchPrecondition(condition: .onQueue(handleQueue))
        socket?.removeAllHandlers()
        manager?.disconnect()
        socket = nil
        manager = nil
    }

    private static func encodeObject<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WhisperSocketError.invalidPayload
        }
        return object
    }

    private static func decodeAcknowledgement<Response: Decodable>(
        _ data: [Any],
        as response: Response.Type
    ) throws -> Response {
        guard let object = data.first as? [String: Any] else {
            throw WhisperSocketError.invalidPayload
        }
        if object["ok"] as? Bool == false {
            let message = object["error"] as? String ?? "unknown socket acknowledgement error"
            throw WhisperSocketError.acknowledgementFailed(message)
        }

        let encoded = try JSONSerialization.data(withJSONObject: object)
        do {
            return try JSONDecoder().decode(response, from: encoded)
        } catch {
            throw WhisperSocketError.invalidPayload
        }
    }

    private static func decodeArguments(_ items: [Any]) -> [WhisperJSONValue] {
        guard JSONSerialization.isValidJSONObject(items),
              let data = try? JSONSerialization.data(withJSONObject: items),
              let arguments = try? JSONDecoder().decode([WhisperJSONValue].self, from: data)
        else {
            return []
        }
        return arguments
    }

    private static func describe(_ values: [Any]) -> String {
        guard values.isEmpty == false else { return "unknown Socket.IO error" }
        return values.map { String(describing: $0) }.joined(separator: ", ")
    }
}
