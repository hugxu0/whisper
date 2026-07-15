import Foundation
import Testing
import WhisperClients
import WhisperDomain
import WhisperFeatures

@Suite("Whisper session flow")
struct SessionFlowTests {
    @Test("login, bootstrap, and socket connection complete as one flow")
    @MainActor
    func startLoadsBootstrapAndConnects() async throws {
        let transport = WhisperStubHTTPClient(responses: [
            "POST /api/v2/login": WhisperHTTPResponse(
                statusCode: 200,
                data: Data(#"{"token":"fixture-token-not-valid","username":"xu","name":"小旭","deviceId":"dev_fixture_xu"}"#.utf8)
            ),
            "GET /api/bootstrap": WhisperHTTPResponse(
                statusCode: 200,
                data: bootstrapData
            )
        ])
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let api = WhisperAPIClient(
            transport: transport,
            configuration: WhisperAPIConfiguration(baseURL: baseURL)
        )
        let socket = WhisperStubSocketClient()
        let controller = WhisperSessionController(api: api, socket: socket)

        await controller.start(request: loginRequest)

        #expect(controller.state.account?.username == "xu")
        #expect(controller.state.bootstrap?.ok == true)
        #expect(controller.state.connection == .connected)
        let connectedToken = await socket.currentToken()
        #expect(connectedToken == "fixture-token-not-valid")

        let requests = await transport.requests()
        #expect(requests.map(\.routeKey) == ["POST /api/v2/login", "GET /api/bootstrap"])
        let encodedLogin = try #require(requests[0].body)
        let sentLogin = try JSONDecoder().decode(WhisperLoginRequest.self, from: encodedLogin)
        #expect(sentLogin.username == "xu")
        #expect(sentLogin.device.platform == "ios")
        #expect(requests[1].headers["Authorization"] == "Bearer fixture-token-not-valid")
    }

    @Test("socket failure is visible and retry can recover")
    @MainActor
    func socketFailureIsRetryable() async throws {
        let transport = WhisperStubHTTPClient(responses: [
            "POST /api/v2/login": WhisperHTTPResponse(
                statusCode: 200,
                data: Data(#"{"token":"fixture-token-not-valid","username":"xu","name":"小旭","deviceId":"dev_fixture_xu"}"#.utf8)
            ),
            "GET /api/bootstrap": WhisperHTTPResponse(statusCode: 200, data: bootstrapData)
        ])
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let api = WhisperAPIClient(
            transport: transport,
            configuration: WhisperAPIConfiguration(baseURL: baseURL)
        )
        let socket = WhisperStubSocketClient(connectError: .connectionFailed("fixture offline"))
        let controller = WhisperSessionController(api: api, socket: socket)

        await controller.start(request: loginRequest)

        #expect(controller.state.connection == .failed("connectionFailed(\"fixture offline\")"))
        #expect(controller.state.lastError != nil)
        #expect(controller.state.bootstrap?.ok == true)

        await socket.setConnectError(nil)
        await controller.retry(request: loginRequest)

        #expect(controller.state.connection == .connected)
    }

    private var loginRequest: WhisperLoginRequest {
        WhisperLoginRequest(
            username: "xu",
            password: "fixture-password-not-valid",
            device: WhisperDeviceDescription(
                installationId: "installation_fixture_xu",
                deviceName: "Whisper Fixture Device",
                appVersion: "0.1.0",
                buildNumber: "1",
                locale: "zh_CN",
                timezone: "Asia/Shanghai"
            )
        )
    }

    private var bootstrapData: Data {
        Data(#"{"ok":true,"serverTime":1700000000000,"accounts":[{"username":"xu","name":"小旭","avatar":null}],"messages":{"couple":[],"ai":[]},"readStates":{"couple":{},"ai":{}},"sharedState":{}}"#.utf8)
    }
}
