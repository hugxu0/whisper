import Foundation
import Observation
import WhisperClients
import WhisperDomain

public enum WhisperMessageDeliveryState: Equatable, Sendable {
    case sending
    case sent
    case failed(String)
}

public struct WhisperChatEntry: Identifiable, Equatable, Sendable {
    public let localID: String
    public let message: WhisperMessage
    public var delivery: WhisperMessageDeliveryState

    public var id: String { localID }

    public init(
        localID: String,
        message: WhisperMessage,
        delivery: WhisperMessageDeliveryState
    ) {
        self.localID = localID
        self.message = message
        self.delivery = delivery
    }
}

public struct WhisperChatState: Equatable, Sendable {
    public var channel: WhisperChannel
    public var currentUsername: String?
    public var currentAccountName: String?
    public var messagesByChannel: [WhisperChannel: [WhisperChatEntry]]
    public var isSending: Bool
    public var isListening: Bool
    public var lastError: String?

    public init(
        channel: WhisperChannel = .couple,
        currentUsername: String? = nil,
        currentAccountName: String? = nil,
        messagesByChannel: [WhisperChannel: [WhisperChatEntry]] = [:],
        isSending: Bool = false,
        isListening: Bool = false,
        lastError: String? = nil
    ) {
        self.channel = channel
        self.currentUsername = currentUsername
        self.currentAccountName = currentAccountName
        self.messagesByChannel = messagesByChannel
        self.isSending = isSending
        self.isListening = isListening
        self.lastError = lastError
    }

    public var visibleEntries: [WhisperChatEntry] {
        messagesByChannel[channel] ?? []
    }
}

public enum WhisperChatAction: Equatable, Sendable {
    case loaded(
        messagesByChannel: [WhisperChannel: [WhisperMessage]],
        currentUsername: String,
        currentAccountName: String?
    )
    case selectChannel(WhisperChannel)
    case sendRequested(entry: WhisperChatEntry, request: WhisperMessageSend)
    case sendSucceeded(WhisperMessageSendAck)
    case sendFailed(clientId: String, message: String)
    case socketEvent(WhisperSocketEventEnvelope)
}

public enum WhisperChatEffect: Equatable, Sendable {
    case send(WhisperMessageSend)
}

public enum WhisperChatFeature {
    @discardableResult
    public static func reduce(
        state: inout WhisperChatState,
        action: WhisperChatAction
    ) -> WhisperChatEffect? {
        switch action {
        case .loaded(let messagesByChannel, let username, let accountName):
            state.currentUsername = username
            state.currentAccountName = accountName
            state.messagesByChannel = WhisperChannel.allCases.reduce(into: [:]) { result, channel in
                result[channel] = normalizedEntries(messagesByChannel[channel] ?? [])
            }
            state.lastError = nil
            state.isSending = false

        case .selectChannel(let channel):
            state.channel = channel
            state.lastError = nil

        case .sendRequested(let entry, let request):
            upsert(entry, in: &state.messagesByChannel)
            state.isSending = true
            state.lastError = nil
            return .send(request)

        case .sendSucceeded(let acknowledgement):
            upsert(
                WhisperChatEntry(
                    localID: acknowledgement.message.id,
                    message: acknowledgement.message,
                    delivery: .sent
                ),
                in: &state.messagesByChannel
            )
            state.isSending = false
            state.lastError = nil

        case .sendFailed(let clientId, let message):
            for channel in WhisperChannel.allCases {
                guard var entries = state.messagesByChannel[channel],
                      let index = entries.firstIndex(where: {
                          $0.message.clientId == clientId
                      })
                else { continue }
                entries[index].delivery = .failed(message)
                state.messagesByChannel[channel] = entries
            }
            state.isSending = false
            state.lastError = message

        case .socketEvent(let envelope):
            guard envelope.name == WhisperSocketEvent.messageNew.rawValue
                    || envelope.name == WhisperSocketEvent.messageUpdate.rawValue,
                  let message = decodeMessage(from: envelope)
            else { return nil }

            let wasPending = state.messagesByChannel[message.channel, default: []].contains {
                $0.message.clientId != nil && $0.message.clientId == message.clientId
            }
            upsert(
                WhisperChatEntry(
                    localID: message.id,
                    message: message,
                    delivery: .sent
                ),
                in: &state.messagesByChannel
            )
            if wasPending {
                state.isSending = false
                state.lastError = nil
            }
        }

        return nil
    }

    private static func decodeMessage(
        from envelope: WhisperSocketEventEnvelope
    ) -> WhisperMessage? {
        guard let argument = envelope.arguments.first,
              let data = try? JSONEncoder().encode(argument)
        else { return nil }
        return try? JSONDecoder().decode(WhisperMessage.self, from: data)
    }

    private static func normalizedEntries(
        _ messages: [WhisperMessage]
    ) -> [WhisperChatEntry] {
        var entries: [WhisperChatEntry] = []
        for message in messages {
            upsert(
                WhisperChatEntry(
                    localID: message.id,
                    message: message,
                    delivery: .sent
                ),
                in: &entries
            )
        }
        return entries
    }

    private static func upsert(
        _ entry: WhisperChatEntry,
        in messagesByChannel: inout [WhisperChannel: [WhisperChatEntry]]
    ) {
        var entries = messagesByChannel[entry.message.channel, default: []]
        upsert(entry, in: &entries)
        messagesByChannel[entry.message.channel] = entries
    }

    private static func upsert(
        _ entry: WhisperChatEntry,
        in entries: inout [WhisperChatEntry]
    ) {
        let index = entries.firstIndex { existing in
            let sameClient = entry.message.clientId != nil
                && existing.message.clientId == entry.message.clientId
            return sameClient || existing.message.id == entry.message.id
        }

        if let index {
            entries[index] = WhisperChatEntry(
                localID: entries[index].localID,
                message: entry.message,
                delivery: entry.delivery
            )
        } else {
            entries.append(entry)
        }

        entries.sort {
            if $0.message.ts == $1.message.ts {
                return $0.localID < $1.localID
            }
            return $0.message.ts < $1.message.ts
        }
    }
}

@MainActor
@Observable
public final class WhisperChatController {
    public private(set) var state: WhisperChatState

    private let socket: any WhisperSocketMessagingClient
    private let idGenerator: @Sendable () -> String
    private let clock: @Sendable () -> Int64

    public init(
        socket: any WhisperSocketMessagingClient,
        state: WhisperChatState = WhisperChatState(),
        idGenerator: @escaping @Sendable () -> String = {
            UUID().uuidString.lowercased()
        },
        clock: @escaping @Sendable () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1_000)
        }
    ) {
        self.socket = socket
        self.state = state
        self.idGenerator = idGenerator
        self.clock = clock
    }

    public func load(
        bootstrap: WhisperBootstrapResponse,
        username: String,
        accountName: String?
    ) {
        dispatch(
            .loaded(
                messagesByChannel: bootstrap.messages,
                currentUsername: username,
                currentAccountName: accountName
            )
        )
    }

    public func selectChannel(_ channel: WhisperChannel) {
        dispatch(.selectChannel(channel))
    }

    public func sendText(_ text: String) async {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false, state.isSending == false else { return }

        let clientId = idGenerator()
        let request = WhisperMessageSend(
            channel: state.channel,
            type: .text,
            text: normalizedText,
            clientId: clientId
        )
        let pendingMessage = WhisperMessage(
            id: "local:\(clientId)",
            sender: state.currentUsername ?? "unknown",
            senderName: state.currentAccountName,
            kind: "user",
            type: .text,
            text: normalizedText,
            channel: state.channel,
            ts: clock(),
            clientId: clientId
        )
        let pendingEntry = WhisperChatEntry(
            localID: "local:\(clientId)",
            message: pendingMessage,
            delivery: .sending
        )

        guard dispatch(.sendRequested(entry: pendingEntry, request: request)) != nil else {
            return
        }

        do {
            let acknowledgement = try await socket.sendMessage(request)
            dispatch(.sendSucceeded(acknowledgement))
        } catch {
            dispatch(
                .sendFailed(
                    clientId: clientId,
                    message: String(describing: error)
                )
            )
        }
    }

    public func retry(entryID: String) async {
        guard let entry = state.visibleEntries.first(where: { $0.id == entryID }),
              case .failed = entry.delivery,
              let clientId = entry.message.clientId
        else { return }

        let request = WhisperMessageSend(
            channel: entry.message.channel,
            type: entry.message.type,
            text: entry.message.text,
            url: entry.message.url,
            uploadId: entry.message.attachments?.first?.uploadId,
            replyTo: entry.message.replyTo,
            replyPreview: entry.message.replyPreview,
            attachments: entry.message.attachments,
            meta: entry.message.meta,
            clientId: clientId
        )
        let pending = WhisperChatEntry(
            localID: entry.localID,
            message: entry.message,
            delivery: .sending
        )
        guard dispatch(.sendRequested(entry: pending, request: request)) != nil else {
            return
        }

        do {
            let acknowledgement = try await socket.sendMessage(request)
            dispatch(.sendSucceeded(acknowledgement))
        } catch {
            dispatch(
                .sendFailed(
                    clientId: clientId,
                    message: String(describing: error)
                )
            )
        }
    }

    public func monitorEvents() async {
        state.isListening = true
        let events = await socket.events()
        for await event in events {
            guard Task.isCancelled == false else { break }
            dispatch(.socketEvent(event))
        }
        state.isListening = false
    }

    @discardableResult
    private func dispatch(_ action: WhisperChatAction) -> WhisperChatEffect? {
        WhisperChatFeature.reduce(state: &state, action: action)
    }
}
