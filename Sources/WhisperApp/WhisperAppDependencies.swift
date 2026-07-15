import Foundation
import WhisperClients
import WhisperDomain
import WhisperFeatures
import WhisperSocketIO

@MainActor
public struct WhisperAppDependencies {
    public let sessionController: WhisperSessionController
    public let chatController: WhisperChatController

    public init(
        sessionAPI: any WhisperSessionAPI,
        chatAPI: (any WhisperChatAPI)? = nil,
        socketClient: any WhisperSocketMessagingClient,
        outbox: any WhisperOutboxClient = WhisperInMemoryOutboxClient()
    ) {
        self.sessionController = WhisperSessionController(
            api: sessionAPI,
            socket: socketClient
        )
        self.chatController = WhisperChatController(
            socket: socketClient,
            api: chatAPI,
            outbox: outbox
        )
    }

    private init(
        sessionController: WhisperSessionController,
        chatController: WhisperChatController
    ) {
        self.sessionController = sessionController
        self.chatController = chatController
    }

    public static func live(baseURL: URL) -> WhisperAppDependencies {
        let transport = WhisperURLSessionHTTPClient()
        let api = WhisperAPIClient(
            transport: transport,
            configuration: WhisperAPIConfiguration(baseURL: baseURL)
        )
        let socket = WhisperSocketIOClient(baseURL: baseURL)
        return WhisperAppDependencies(
            sessionAPI: api,
            chatAPI: api,
            socketClient: socket,
            outbox: WhisperFileOutboxClient.live()
        )
    }

    public static func chatAcceptancePreview() -> WhisperAppDependencies {
        let bootstrap = WhisperChatAcceptanceFixture.bootstrap
        let socket = WhisperStubSocketClient()
        let api = WhisperPreviewSessionAPI(bootstrap: bootstrap)
        var sessionState = WhisperSessionState()
        sessionState.account = bootstrap.accounts[0]
        sessionState.bootstrap = bootstrap
        sessionState.connection = .connected

        return WhisperAppDependencies(
            sessionController: WhisperSessionController(
                api: api,
                socket: socket,
                state: sessionState
            ),
            chatController: WhisperChatController(socket: socket)
        )
    }
}

private actor WhisperPreviewSessionAPI: WhisperSessionAPI {
    let bootstrapResponse: WhisperBootstrapResponse

    init(bootstrap: WhisperBootstrapResponse) {
        self.bootstrapResponse = bootstrap
    }

    func login(_ request: WhisperLoginRequest) -> WhisperLoginResponse {
        WhisperLoginResponse(
            token: "preview-token-not-valid",
            username: "xu",
            name: "小旭",
            deviceId: "preview-device"
        )
    }

    func bootstrap() -> WhisperBootstrapResponse {
        bootstrapResponse
    }
}

private enum WhisperChatAcceptanceFixture {
    static let bootstrap = WhisperBootstrapResponse(
        ok: true,
        serverTime: 1_700_000_000_000,
        accounts: [
            WhisperAccount(username: "xu", name: "小旭"),
            WhisperAccount(username: "si", name: "小偲")
        ],
        messages: [
            .couple: [
                message(id: "preview-1", sender: "si", text: "今晚早点睡，明天一起去吃好吃的", ts: 1_700_000_000_000),
                message(id: "preview-2", sender: "xu", text: "好，忙完就回家", ts: 1_700_000_060_000),
                message(id: "preview-3", sender: "si", text: "🥰", ts: 1_700_000_120_000),
                message(
                    id: "preview-4",
                    sender: "xu",
                    text: "我也想你",
                    replyTo: "preview-1",
                    replyPreview: "今晚早点睡，明天一起去吃好吃的",
                    ts: 1_700_000_180_000
                ),
                WhisperMessage(
                    id: "preview-5",
                    sender: "si",
                    senderName: "小偲",
                    kind: "user",
                    type: .sticker,
                    text: "[表情]",
                    channel: .couple,
                    ts: 1_700_000_240_000
                ),
                message(id: "preview-6", sender: "xu", text: "聊天页的尺寸、气泡和输入栏现在统一验收", ts: 1_700_000_300_000)
            ],
            .ai: []
        ],
        readStates: WhisperReadStates(couple: ["si": 1_700_000_300_000]),
        sharedState: [:]
    )

    private static func message(
        id: String,
        sender: String,
        text: String,
        replyTo: String? = nil,
        replyPreview: String? = nil,
        ts: Int64
    ) -> WhisperMessage {
        WhisperMessage(
            id: id,
            sender: sender,
            senderName: sender == "xu" ? "小旭" : "小偲",
            kind: "user",
            type: .text,
            text: text,
            replyTo: replyTo,
            replyPreview: replyPreview,
            channel: .couple,
            ts: ts,
            clientId: "client-\(id)"
        )
    }
}
