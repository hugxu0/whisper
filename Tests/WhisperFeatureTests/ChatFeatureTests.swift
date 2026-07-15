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
        #expect(controller.state.visibleEntries[0].delivery == .sent)
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
}
