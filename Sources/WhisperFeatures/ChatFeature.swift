import Foundation
import Observation
import WhisperClients
import WhisperDomain

public enum WhisperMessageDeliveryState: Equatable, Sendable {
    case uploading(Double?)
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
    public var readStatesByChannel: [WhisperChannel: [String: Int64]]
    public var totalsByChannel: [WhisperChannel: Int]
    public var hasEarlierByChannel: [WhisperChannel: Bool]
    public var isSending: Bool
    public var isListening: Bool
    public var isLoadingEarlier: Bool
    public var isSyncing: Bool
    public var syncCursor: Int64
    public var searchResults: [WhisperMessage]
    public var isSearching: Bool
    public var lastError: String?

    public init(
        channel: WhisperChannel = .couple,
        currentUsername: String? = nil,
        currentAccountName: String? = nil,
        messagesByChannel: [WhisperChannel: [WhisperChatEntry]] = [:],
        readStatesByChannel: [WhisperChannel: [String: Int64]] = [:],
        totalsByChannel: [WhisperChannel: Int] = [:],
        hasEarlierByChannel: [WhisperChannel: Bool] = [:],
        isSending: Bool = false,
        isListening: Bool = false,
        isLoadingEarlier: Bool = false,
        isSyncing: Bool = false,
        syncCursor: Int64 = 0,
        searchResults: [WhisperMessage] = [],
        isSearching: Bool = false,
        lastError: String? = nil
    ) {
        self.channel = channel
        self.currentUsername = currentUsername
        self.currentAccountName = currentAccountName
        self.messagesByChannel = messagesByChannel
        self.readStatesByChannel = readStatesByChannel
        self.totalsByChannel = totalsByChannel
        self.hasEarlierByChannel = hasEarlierByChannel
        self.isSending = isSending
        self.isListening = isListening
        self.isLoadingEarlier = isLoadingEarlier
        self.isSyncing = isSyncing
        self.syncCursor = syncCursor
        self.searchResults = searchResults
        self.isSearching = isSearching
        self.lastError = lastError
    }

    public var visibleEntries: [WhisperChatEntry] {
        messagesByChannel[channel] ?? []
    }

    public var hasEarlierMessages: Bool {
        hasEarlierByChannel[channel] ?? false
    }

    public func readTimestamp(for username: String, channel: WhisperChannel? = nil) -> Int64 {
        readStatesByChannel[channel ?? self.channel]?[username] ?? 0
    }
}

public enum WhisperChatAction: Equatable, Sendable {
    case loaded(
        messagesByChannel: [WhisperChannel: [WhisperMessage]],
        readStatesByChannel: [WhisperChannel: [String: Int64]],
        currentUsername: String,
        currentAccountName: String?
    )
    case selectChannel(WhisperChannel)
    case restoredOutbox([WhisperOutboxItem])
    case olderLoadStarted
    case olderLoaded(channel: WhisperChannel, messages: [WhisperMessage], total: Int)
    case olderLoadFailed(String)
    case syncStarted
    case syncPage(events: [WhisperSyncEvent], cursor: Int64)
    case syncFinished
    case syncFailed(String)
    case pendingInserted(WhisperChatEntry)
    case sendRequested(entry: WhisperChatEntry, request: WhisperMessageSend)
    case uploadProgress(clientID: String, progress: Double?)
    case sendSucceeded(WhisperMessageSendAck)
    case sendFailed(clientId: String, message: String)
    case messageRecalled(id: String, channel: WhisperChannel, notice: WhisperMessage?, cursor: Int64?)
    case readUpdated(WhisperReadUpdate)
    case searchStarted
    case searchFinished([WhisperMessage])
    case searchFailed(String)
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
        case .loaded(let messagesByChannel, let readStates, let username, let accountName):
            state.currentUsername = username
            state.currentAccountName = accountName
            state.messagesByChannel = WhisperChannel.allCases.reduce(into: [:]) { result, channel in
                result[channel] = normalizedEntries(messagesByChannel[channel] ?? [])
            }
            state.readStatesByChannel = readStates
            state.hasEarlierByChannel = WhisperChannel.allCases.reduce(into: [:]) { result, channel in
                result[channel] = (messagesByChannel[channel]?.count ?? 0) >= 40
            }
            state.lastError = nil
            refreshSendingState(&state)

        case .selectChannel(let channel):
            state.channel = channel
            state.lastError = nil

        case .restoredOutbox(let items):
            for item in items {
                upsert(
                    WhisperChatEntry(
                        localID: "local:\(item.request.clientId)",
                        message: item.message,
                        delivery: .failed("等待重发")
                    ),
                    in: &state.messagesByChannel
                )
            }
            refreshSendingState(&state)

        case .olderLoadStarted:
            state.isLoadingEarlier = true

        case .olderLoaded(let channel, let messages, let total):
            for message in messages {
                upsert(sentEntry(message), in: &state.messagesByChannel)
            }
            state.totalsByChannel[channel] = total
            state.hasEarlierByChannel[channel] = state.messagesByChannel[channel, default: []].count < total
            state.isLoadingEarlier = false
            state.lastError = nil

        case .olderLoadFailed(let message):
            state.isLoadingEarlier = false
            state.lastError = message

        case .syncStarted:
            state.isSyncing = true

        case .syncPage(let events, let cursor):
            for event in events where event.entityType == "message" {
                if event.operation == "delete" {
                    remove(messageID: event.entityId, from: &state.messagesByChannel)
                } else if let message = decodeMessage(from: event.payload) {
                    upsert(sentEntry(message), in: &state.messagesByChannel)
                }
            }
            state.syncCursor = max(state.syncCursor, cursor)

        case .syncFinished:
            state.isSyncing = false
            state.lastError = nil

        case .syncFailed(let message):
            state.isSyncing = false
            state.lastError = message

        case .pendingInserted(let entry):
            upsert(entry, in: &state.messagesByChannel)
            refreshSendingState(&state)

        case .sendRequested(let entry, let request):
            upsert(entry, in: &state.messagesByChannel)
            state.lastError = nil
            refreshSendingState(&state)
            return .send(request)

        case .uploadProgress(let clientID, let progress):
            updateDelivery(clientID: clientID, delivery: .uploading(progress), state: &state)

        case .sendSucceeded(let acknowledgement):
            upsert(sentEntry(acknowledgement.message), in: &state.messagesByChannel)
            state.lastError = nil
            refreshSendingState(&state)

        case .sendFailed(let clientId, let message):
            updateDelivery(clientID: clientId, delivery: .failed(message), state: &state)
            state.lastError = message

        case .messageRecalled(let id, let channel, let notice, let cursor):
            remove(messageID: id, channel: channel, from: &state.messagesByChannel)
            if let notice {
                upsert(sentEntry(notice), in: &state.messagesByChannel)
            }
            if let cursor {
                state.syncCursor = max(state.syncCursor, cursor)
            }

        case .readUpdated(let update):
            let previous = state.readStatesByChannel[update.channel]?[update.user] ?? 0
            state.readStatesByChannel[update.channel, default: [:]][update.user] = max(previous, update.ts)

        case .searchStarted:
            state.isSearching = true
            state.searchResults = []

        case .searchFinished(let messages):
            state.isSearching = false
            state.searchResults = messages.sorted { $0.ts > $1.ts }
            state.lastError = nil

        case .searchFailed(let message):
            state.isSearching = false
            state.lastError = message

        case .socketEvent(let envelope):
            consumeSocketEvent(envelope, state: &state)
        }

        return nil
    }

    private static func consumeSocketEvent(
        _ envelope: WhisperSocketEventEnvelope,
        state: inout WhisperChatState
    ) {
        switch envelope.name {
        case WhisperSocketEvent.messageNew.rawValue,
             WhisperSocketEvent.messageUpdate.rawValue:
            guard let value = envelope.arguments.first,
                  let message = decodeMessage(from: value)
            else { return }
            upsert(sentEntry(message), in: &state.messagesByChannel)
            state.lastError = nil
            refreshSendingState(&state)

        case WhisperSocketEvent.messageRecalled.rawValue:
            guard let value = envelope.arguments.first,
                  let event = decode(WhisperMessageRecalledEvent.self, from: value)
            else { return }
            remove(messageID: event.id, channel: event.channel, from: &state.messagesByChannel)
            if let notice = event.notice {
                upsert(sentEntry(notice), in: &state.messagesByChannel)
            }
            if let cursor = event.syncCursor {
                state.syncCursor = max(state.syncCursor, cursor)
            }

        case WhisperSocketEvent.readUpdate.rawValue:
            guard let value = envelope.arguments.first,
                  let update = decode(WhisperReadUpdate.self, from: value)
            else { return }
            let previous = state.readStatesByChannel[update.channel]?[update.user] ?? 0
            state.readStatesByChannel[update.channel, default: [:]][update.user] = max(previous, update.ts)

        default:
            return
        }
    }

    private static func decodeMessage(from value: WhisperJSONValue) -> WhisperMessage? {
        decode(WhisperMessage.self, from: value)
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        from value: WhisperJSONValue
    ) -> Value? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func normalizedEntries(_ messages: [WhisperMessage]) -> [WhisperChatEntry] {
        var entries: [WhisperChatEntry] = []
        for message in messages {
            upsert(sentEntry(message), in: &entries)
        }
        return entries
    }

    private static func sentEntry(_ message: WhisperMessage) -> WhisperChatEntry {
        WhisperChatEntry(localID: message.id, message: message, delivery: .sent)
    }

    private static func upsert(
        _ entry: WhisperChatEntry,
        in messagesByChannel: inout [WhisperChannel: [WhisperChatEntry]]
    ) {
        var entries = messagesByChannel[entry.message.channel, default: []]
        upsert(entry, in: &entries)
        messagesByChannel[entry.message.channel] = entries
    }

    private static func upsert(_ entry: WhisperChatEntry, in entries: inout [WhisperChatEntry]) {
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
            if $0.message.ts == $1.message.ts { return $0.localID < $1.localID }
            return $0.message.ts < $1.message.ts
        }
    }

    private static func remove(
        messageID: String,
        channel: WhisperChannel? = nil,
        from messagesByChannel: inout [WhisperChannel: [WhisperChatEntry]]
    ) {
        let channels = channel.map { [$0] } ?? WhisperChannel.allCases
        for channel in channels {
            messagesByChannel[channel]?.removeAll { $0.message.id == messageID }
        }
    }

    private static func updateDelivery(
        clientID: String,
        delivery: WhisperMessageDeliveryState,
        state: inout WhisperChatState
    ) {
        for channel in WhisperChannel.allCases {
            guard var entries = state.messagesByChannel[channel],
                  let index = entries.firstIndex(where: { $0.message.clientId == clientID })
            else { continue }
            entries[index].delivery = delivery
            state.messagesByChannel[channel] = entries
        }
        refreshSendingState(&state)
    }

    private static func refreshSendingState(_ state: inout WhisperChatState) {
        state.isSending = state.messagesByChannel.values.joined().contains { entry in
            switch entry.delivery {
            case .uploading, .sending: return true
            case .sent, .failed: return false
            }
        }
    }
}

@MainActor
@Observable
public final class WhisperChatController {
    public private(set) var state: WhisperChatState

    private let socket: any WhisperSocketMessagingClient
    private let api: (any WhisperChatAPI)?
    private let outbox: any WhisperOutboxClient
    private let idGenerator: @Sendable () -> String
    private let clock: @Sendable () -> Int64
    @ObservationIgnored private var lastReadSentByChannel: [WhisperChannel: Int64] = [:]

    public init(
        socket: any WhisperSocketMessagingClient,
        api: (any WhisperChatAPI)? = nil,
        outbox: any WhisperOutboxClient = WhisperInMemoryOutboxClient(),
        state: WhisperChatState = WhisperChatState(),
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        clock: @escaping @Sendable () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1_000)
        }
    ) {
        self.socket = socket
        self.api = api
        self.outbox = outbox
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
                readStatesByChannel: [
                    .couple: bootstrap.readStates.couple,
                    .ai: bootstrap.readStates.ai
                ],
                currentUsername: username,
                currentAccountName: accountName
            )
        )
    }

    public func selectChannel(_ channel: WhisperChannel) {
        dispatch(.selectChannel(channel))
    }

    public func loadEarlier() async {
        guard let api,
              state.isLoadingEarlier == false,
              state.hasEarlierMessages,
              let before = state.visibleEntries.first?.message.ts
        else { return }

        let channel = state.channel
        dispatch(.olderLoadStarted)
        do {
            let page = try await api.messages(
                WhisperMessagePageRequest(channel: channel, before: before, limit: 60)
            )
            dispatch(.olderLoaded(channel: channel, messages: page.list, total: page.total))
        } catch {
            dispatch(.olderLoadFailed(String(describing: error)))
        }
    }

    public func loadAround(_ message: WhisperMessage) async {
        guard let api else { return }
        do {
            let page = try await api.messages(
                WhisperMessagePageRequest(
                    channel: message.channel,
                    around: message.ts,
                    limit: 80
                )
            )
            if state.channel != message.channel {
                dispatch(.selectChannel(message.channel))
            }
            dispatch(
                .olderLoaded(
                    channel: message.channel,
                    messages: page.list,
                    total: page.total
                )
            )
        } catch {
            state.lastError = String(describing: error)
        }
    }

    public func synchronize() async {
        guard let api, state.isSyncing == false else { return }
        dispatch(.syncStarted)
        var cursor = state.syncCursor
        do {
            while Task.isCancelled == false {
                let page = try await api.sync(cursor: cursor, limit: 200)
                dispatch(.syncPage(events: page.events, cursor: page.nextCursor))
                cursor = page.nextCursor
                try await api.acknowledgeSync(cursor: cursor)
                if page.hasMore == false { break }
            }
            try Task.checkCancellation()
            dispatch(.syncFinished)
        } catch is CancellationError {
            dispatch(.syncFinished)
        } catch {
            dispatch(.syncFailed(String(describing: error)))
        }
    }

    public func restoreOutboxAndRetry() async {
        do {
            let items = try await outbox.load()
            dispatch(.restoredOutbox(items))
            for item in items where Task.isCancelled == false {
                await transmit(entry: entry(for: item), request: item.request, persist: false)
            }
        } catch {
            state.lastError = String(describing: error)
        }
    }

    public func sendText(_ text: String, replyingTo reply: WhisperMessage? = nil) async {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else { return }

        let clientID = idGenerator()
        let request = WhisperMessageSend(
            channel: state.channel,
            type: .text,
            text: normalizedText,
            replyTo: reply?.id,
            replyPreview: reply.map { WhisperMessagePresentation(message: $0).previewText },
            clientId: clientID
        )
        let message = pendingMessage(
            clientID: clientID,
            type: .text,
            text: normalizedText,
            replyTo: reply?.id,
            replyPreview: request.replyPreview
        )
        await transmit(
            entry: WhisperChatEntry(localID: "local:\(clientID)", message: message, delivery: .sending),
            request: request,
            persist: true
        )
    }

    public func sendMedia(
        _ upload: WhisperMediaUpload,
        as type: WhisperMessageType,
        caption: String? = nil,
        localURL: String? = nil
    ) async {
        guard let api, type != .text else { return }
        let clientID = idGenerator()
        let pending = pendingMessage(
            clientID: clientID,
            type: type,
            text: caption ?? upload.filename,
            url: localURL
        )
        dispatch(
            .pendingInserted(
                WhisperChatEntry(
                    localID: "local:\(clientID)",
                    message: pending,
                    delivery: .uploading(nil)
                )
            )
        )

        do {
            let result = try await api.upload(upload)
            let request = WhisperMessageSend(
                channel: state.channel,
                type: type,
                text: caption ?? (type == .file ? upload.filename : nil),
                url: result.url,
                uploadId: type == .sticker ? nil : result.id,
                clientId: clientID
            )
            let uploadedMessage = pendingMessage(
                clientID: clientID,
                type: type,
                text: request.text,
                url: result.url,
                attachments: [
                    WhisperAttachment(
                        assetId: clientID,
                        role: "upload",
                        uploadId: result.id
                    )
                ]
            )
            await transmit(
                entry: WhisperChatEntry(
                    localID: "local:\(clientID)",
                    message: uploadedMessage,
                    delivery: .sending
                ),
                request: request,
                persist: true
            )
        } catch {
            dispatch(.sendFailed(clientId: clientID, message: String(describing: error)))
        }
    }

    public func retry(entryID: String) async {
        guard let entry = state.visibleEntries.first(where: { $0.id == entryID }),
              case .failed = entry.delivery,
              let clientID = entry.message.clientId
        else { return }

        let localUploadID = entry.message.attachments?.first(where: { $0.role == "upload" })?.uploadId
        let serverAttachments = entry.message.attachments?.filter {
            $0.role == "photo" || $0.role == "pairedVideo"
        }
        let request = WhisperMessageSend(
            channel: entry.message.channel,
            type: entry.message.type,
            text: entry.message.text,
            url: entry.message.url,
            uploadId: entry.message.type == .sticker ? nil : localUploadID,
            replyTo: entry.message.replyTo,
            replyPreview: entry.message.replyPreview,
            attachments: serverAttachments?.isEmpty == false ? serverAttachments : nil,
            meta: entry.message.meta,
            clientId: clientID
        )
        await transmit(
            entry: WhisperChatEntry(
                localID: entry.localID,
                message: entry.message,
                delivery: .sending
            ),
            request: request,
            persist: true
        )
    }

    public func recall(entryID: String) async {
        guard let entry = state.visibleEntries.first(where: { $0.id == entryID }) else { return }
        do {
            let acknowledgement = try await socket.recallMessage(id: entry.message.id)
            dispatch(
                .messageRecalled(
                    id: entry.message.id,
                    channel: entry.message.channel,
                    notice: acknowledgement.notice,
                    cursor: nil
                )
            )
        } catch {
            state.lastError = String(describing: error)
        }
    }

    public func search(_ query: String) async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            dispatch(.searchFinished([]))
            return
        }
        dispatch(.searchStarted)
        do {
            let result = try await socket.searchMessages(
                channel: state.channel,
                query: normalized,
                limit: 100
            )
            dispatch(.searchFinished(result.list))
        } catch {
            dispatch(.searchFailed(String(describing: error)))
        }
    }

    public func markLatestRead() async {
        guard let username = state.currentUsername,
              let timestamp = state.visibleEntries.last?.message.ts,
              timestamp > (lastReadSentByChannel[state.channel] ?? 0)
        else { return }
        do {
            try await socket.markRead(channel: state.channel, timestamp: timestamp)
            lastReadSentByChannel[state.channel] = timestamp
            dispatch(.readUpdated(WhisperReadUpdate(channel: state.channel, user: username, ts: timestamp)))
        } catch {
            // Read receipts are best effort; message delivery must remain usable.
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

    private func transmit(
        entry: WhisperChatEntry,
        request: WhisperMessageSend,
        persist: Bool
    ) async {
        guard dispatch(.sendRequested(entry: entry, request: request)) != nil else { return }
        if persist {
            try? await outbox.save(
                WhisperOutboxItem(message: entry.message, request: request, createdAt: clock())
            )
        }
        do {
            let acknowledgement = try await socket.sendMessage(request)
            dispatch(.sendSucceeded(acknowledgement))
            try? await outbox.remove(clientID: request.clientId)
        } catch {
            dispatch(.sendFailed(clientId: request.clientId, message: String(describing: error)))
        }
    }

    private func pendingMessage(
        clientID: String,
        type: WhisperMessageType,
        text: String?,
        url: String? = nil,
        replyTo: String? = nil,
        replyPreview: String? = nil,
        attachments: [WhisperAttachment]? = nil
    ) -> WhisperMessage {
        WhisperMessage(
            id: "local:\(clientID)",
            sender: state.currentUsername ?? "unknown",
            senderName: state.currentAccountName,
            kind: "user",
            type: type,
            text: text,
            url: url,
            replyTo: replyTo,
            replyPreview: replyPreview,
            attachments: attachments,
            channel: state.channel,
            ts: clock(),
            clientId: clientID
        )
    }

    private func entry(for item: WhisperOutboxItem) -> WhisperChatEntry {
        WhisperChatEntry(
            localID: "local:\(item.request.clientId)",
            message: item.message,
            delivery: .sending
        )
    }

    @discardableResult
    private func dispatch(_ action: WhisperChatAction) -> WhisperChatEffect? {
        WhisperChatFeature.reduce(state: &state, action: action)
    }
}
