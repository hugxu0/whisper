import Foundation
import WhisperClients
import WhisperFeatures
import WhisperSocketIO

@MainActor
public struct WhisperAppDependencies {
    public let sessionController: WhisperSessionController
    public let chatController: WhisperChatController

    public init(
        sessionAPI: any WhisperSessionAPI,
        socketClient: any WhisperSocketMessagingClient
    ) {
        self.sessionController = WhisperSessionController(
            api: sessionAPI,
            socket: socketClient
        )
        self.chatController = WhisperChatController(socket: socketClient)
    }

    public static func live(baseURL: URL) -> WhisperAppDependencies {
        let transport = WhisperURLSessionHTTPClient()
        let api = WhisperAPIClient(
            transport: transport,
            configuration: WhisperAPIConfiguration(baseURL: baseURL)
        )
        let socket = WhisperSocketIOClient(baseURL: baseURL)
        return WhisperAppDependencies(sessionAPI: api, socketClient: socket)
    }
}
