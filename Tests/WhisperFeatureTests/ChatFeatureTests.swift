import Foundation
import Testing
import WhisperClients
import WhisperDomain
import WhisperFeatures

@Suite("Whisper chat feature")
struct ChatFeatureTests {
    @Test("bootstrap messages are normalized and channel switching is local")
    func bootstrapMessagesAreSortedPerChannel() throws {
        var state = WhisperChatState()
        let effect = WhisperChatFeature.reduce(
            state: &state,
            action: .loaded(
                messagesByChannel: [
                    .couple: [
                        message(id: "later", sender: "si", ts: 2_000),
                        message(id: "earlier", sender: "xu", ts: 1_000)
                    ],
                    .ai: [message(id: "private", sender: "xu", channel: .ai, ts: 1_500)]
                ],
                readStatesByChannel: [:],
                currentUsername: "xu",
                currentAccountName: "小旭"
            )
        )

        #expect(effect == nil)
        #expect(state.visibleEntries.map(\.message.id) == ["earlier", "later"])
        #expect(state.currentUsername == "xu")

        WhisperChatFeature.reduce(state: &state, action: .selectChannel(.ai))
        #expect(state.visibleEntries.map(\.message.id) == ["private"])
    }

    @Test("message send replaces pending entry with the authoritative ack")
    @MainActor
    func messageSendUsesClientIdAndAck() async {
        let authoritative = message(
            id: "server-message",
            sender: "xu",
            text: "hello",
            ts: 2_000,
            clientId: "client-test-1"
        )
        let socket = WhisperStubSocketClient(
            acknowledgement: WhisperMessageSendAck(ok: true, message: authoritative)
        )
        let controller = WhisperChatController(
            socket: socket,
            idGenerator: { "client-test-1" },
            clock: { 1_000 }
        )
        controller.load(
            bootstrap: bootstrap(messages: [:]),
            username: "xu",
            accountName: "小旭"
        )

        await controller.sendText("hello")

        #expect(controller.state.visibleEntries.count == 1)
        #expect(controller.state.visibleEntries[0].message.id == "server-message")
        #expect(
            controller.state.visibleEntries[0].delivery
                == WhisperMessageDeliveryState.sent
        )
        let requests = await socket.sentMessageRequests()
        #expect(requests.count == 1)
        #expect(requests[0].clientId == "client-test-1")
        #expect(requests[0].text == "hello")
    }

    @Test("send failure leaves a retryable entry")
    @MainActor
    func sendFailureIsVisible() async {
        let socket = WhisperStubSocketClient(
            sendError: .connectionFailed("fixture offline")
        )
        let controller = WhisperChatController(
            socket: socket,
            idGenerator: { "client-failure-1" },
            clock: { 1_000 }
        )
        controller.load(
            bootstrap: bootstrap(messages: [:]),
            username: "xu",
            accountName: "小旭"
        )

        await controller.sendText("retry me")

        #expect(controller.state.visibleEntries.count == 1)
        guard case .failed(let message) = controller.state.visibleEntries[0].delivery else {
            Issue.record("expected a failed delivery state")
            return
        }
        #expect(message == "connectionFailed(\"fixture offline\")")
    }

    @Test("message:new is consumed as an authoritative timeline entry")
    @MainActor
    func incomingMessageEventIsConsumed() async throws {
        let socket = WhisperStubSocketClient()
        let controller = WhisperChatController(socket: socket)
        controller.load(
            bootstrap: bootstrap(messages: [:]),
            username: "xu",
            accountName: "小旭"
        )

        let monitor = Task { @MainActor in
            await controller.monitorEvents()
        }
        await Task.yield()

        let incoming = message(id: "incoming", sender: "si", text: "收到", ts: 2_000)
        let encoded = try JSONEncoder().encode(incoming)
        let value = try JSONDecoder().decode(WhisperJSONValue.self, from: encoded)
        await socket.emit(
            WhisperSocketEventEnvelope(
                name: WhisperSocketEvent.messageNew.rawValue,
                arguments: [value]
            )
        )
        await Task.yield()
        await Task.yield()
        await socket.finishEvents()
        await monitor.value

        #expect(controller.state.visibleEntries.map(\.message.id) == ["incoming"])
        #expect(controller.state.visibleEntries[0].message.text == "收到")
    }

    @Test("message presentation distinguishes emoji stickers and attachments")
    func messagePresentationClassification() {
        let emoji = message(id: "emoji", sender: "xu", text: "🥰", ts: 1_000)
        let compatibilitySticker = message(
            id: "sticker",
            sender: "si",
            text: "[表情]",
            ts: 2_000
        )
        let image = WhisperMessage(
            id: "image",
            sender: "si",
            type: .image,
            text: "照片",
            url: "/media/image",
            channel: .couple,
            ts: 3_000
        )

        #expect(WhisperMessagePresentation(message: emoji).kind == .emoji)
        #expect(WhisperMessagePresentation(message: compatibilitySticker).kind == .sticker)
        #expect(WhisperMessagePresentation(message: image).kind == .image)
        #expect(WhisperMessagePresentation(message: image).media.first?.url == "/media/image")
    }

    @Test("older page prepends messages and preserves server total")
    @MainActor
    func olderPageLoadsBeforeCurrentWindow() async throws {
        let bootstrapMessages = (1...40).map { index in
            message(id: "m\(index)", sender: "si", ts: Int64(index * 1_000))
        }
        let older = message(id: "older", sender: "si", ts: 500)
        let api = WhisperStubChatAPI(
            messagePages: [WhisperMessagePage(ok: true, list: [older], total: 41)]
        )
        let controller = WhisperChatController(socket: WhisperStubSocketClient(), api: api)
        controller.load(
            bootstrap: bootstrap(messages: [.couple: bootstrapMessages]),
            username: "xu",
            accountName: "小旭"
        )

        await controller.loadEarlier()

        #expect(controller.state.visibleEntries.first?.message.id == "older")
        #expect(controller.state.hasEarlierMessages == false)
        let request = try #require(await api.recordedMessageRequests().first)
        #expect(request.before == 1_000)
        #expect(request.channel == .couple)
    }

    @Test("sync applies upserts and deletes then acknowledges cursor")
    @MainActor
    func reconnectSyncConverges() async throws {
        let existing = message(id: "existing", sender: "si", ts: 1_000)
        let incoming = message(id: "incoming-sync", sender: "si", text: "同步", ts: 2_000)
        let value = try jsonValue(incoming)
        let api = WhisperStubChatAPI(
            syncPages: [
                WhisperSyncPage(
                    protocolVersion: 2,
                    events: [
                        WhisperSyncEvent(
                            seq: 1,
                            entityType: "message",
                            entityId: existing.id,
                            operation: "delete",
                            version: 1,
                            payload: .null,
                            createdAt: 2_000
                        ),
                        WhisperSyncEvent(
                            seq: 2,
                            entityType: "message",
                            entityId: incoming.id,
                            operation: "upsert",
                            version: 1,
                            payload: value,
                            createdAt: 2_000
                        )
                    ],
                    nextCursor: 2,
                    hasMore: false
                )
            ]
        )
        let controller = WhisperChatController(socket: WhisperStubSocketClient(), api: api)
        controller.load(
            bootstrap: bootstrap(messages: [.couple: [existing]]),
            username: "xu",
            accountName: "小旭"
        )

        await controller.synchronize()

        #expect(controller.state.visibleEntries.map(\.message.id) == ["incoming-sync"])
        #expect(controller.state.syncCursor == 2)
        #expect(await api.recordedAcknowledgedCursors() == [2])
    }

    @Test("media upload precedes authoritative message send")
    @MainActor
    func mediaUploadThenSend() async {
        let authoritative = WhisperMessage(
            id: "server-image",
            sender: "xu",
            type: .image,
            url: "/media/up_fixture_image_001",
            channel: .couple,
            ts: 2_000,
            clientId: "media-client"
        )
        let socket = WhisperStubSocketClient(
            acknowledgement: WhisperMessageSendAck(ok: true, message: authoritative)
        )
        let api = WhisperStubChatAPI(
            uploadResult: WhisperUploadResult(
                id: "up_fixture_image_001",
                url: "/media/up_fixture_image_001",
                mimeType: "image/jpeg",
                size: 4,
                type: "image"
            )
        )
        let controller = WhisperChatController(
            socket: socket,
            api: api,
            idGenerator: { "media-client" },
            clock: { 1_000 }
        )
        controller.load(
            bootstrap: bootstrap(messages: [:]),
            username: "xu",
            accountName: "小旭"
        )

        await controller.sendMedia(
            WhisperMediaUpload(data: Data([0xFF, 0xD8, 0xFF, 0xD9]), filename: "photo.jpg", mimeType: "image/jpeg"),
            as: .image
        )

        #expect(await api.recordedUploads().count == 1)
        #expect(await socket.sentMessageRequests().first?.uploadId == "up_fixture_image_001")
        #expect(controller.state.visibleEntries.first?.message.id == "server-image")
    }

    @Test("recall event removes the original message and read receipt advances")
    @MainActor
    func recallAndReadEventsAreConsumed() async throws {
        let original = message(id: "recall-me", sender: "xu", ts: 1_000)
        var state = WhisperChatState(
            currentUsername: "xu",
            messagesByChannel: [
                .couple: [WhisperChatEntry(localID: original.id, message: original, delivery: .sent)]
            ]
        )
        WhisperChatFeature.reduce(
            state: &state,
            action: .socketEvent(
                WhisperSocketEventEnvelope(
                    name: WhisperSocketEvent.messageRecalled.rawValue,
                    arguments: [try jsonValue(
                        WhisperMessageRecalledEvent(
                            id: original.id,
                            channel: .couple,
                            deleted: true,
                            syncCursor: 9
                        )
                    )]
                )
            )
        )
        WhisperChatFeature.reduce(
            state: &state,
            action: .socketEvent(
                WhisperSocketEventEnvelope(
                    name: WhisperSocketEvent.readUpdate.rawValue,
                    arguments: [try jsonValue(
                        WhisperReadUpdate(channel: .couple, user: "si", ts: 2_000)
                    )]
                )
            )
        )

        #expect(state.visibleEntries.isEmpty)
        #expect(state.syncCursor == 9)
        #expect(state.readTimestamp(for: "si") == 2_000)
    }

    private func message(
        id: String,
        sender: String,
        text: String = "fixture",
        channel: WhisperChannel = .couple,
        ts: Int64,
        clientId: String? = nil
    ) -> WhisperMessage {
        WhisperMessage(
            id: id,
            sender: sender,
            senderName: sender == "xu" ? "小旭" : "小偲",
            kind: "user",
            type: .text,
            text: text,
            channel: channel,
            ts: ts,
            clientId: clientId
        )
    }

    private func bootstrap(
        messages: [WhisperChannel: [WhisperMessage]]
    ) -> WhisperBootstrapResponse {
        WhisperBootstrapResponse(
            ok: true,
            serverTime: 1_000,
            accounts: [WhisperAccount(username: "xu", name: "小旭")],
            messages: messages,
            readStates: WhisperReadStates(),
            sharedState: [:]
        )
    }

    private func jsonValue<Value: Encodable>(_ value: Value) throws -> WhisperJSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(WhisperJSONValue.self, from: data)
    }
}
