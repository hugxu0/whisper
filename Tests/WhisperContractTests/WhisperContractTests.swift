import Foundation
import Testing
import WhisperDomain
import WhisperClients

@Suite("Whisper retained contract")
struct WhisperContractTests {
    @Test("message send keeps server field names and client id")
    func messageSendEncoding() throws {
        let payload = WhisperMessageSend(
            channel: .couple,
            type: .text,
            text: "fixture send",
            clientId: "client_fixture_send_001"
        )

        let data = try JSONEncoder().encode(payload)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"clientId\""))
        #expect(json.contains("\"channel\":\"couple\""))
        #expect(json.contains("\"type\":\"text\""))
    }

    @Test("bootstrap response decodes channel-keyed messages")
    func bootstrapDecoding() throws {
        let data = Data(#"{"ok":true,"serverTime":1700000000000,"accounts":[{"username":"xu","name":"小旭","avatar":null}],"messages":{"couple":[{"id":"msg_fixture_001","sender":"xu","senderName":"小旭","kind":"user","type":"text","text":"fixture message","url":null,"replyTo":null,"replyPreview":null,"reply":null,"meta":null,"attachments":null,"recalledText":null,"channel":"couple","ts":1700000000000,"clientId":"client_fixture_001"}],"ai":[]},"readStates":{"couple":{},"ai":{}},"sharedState":{}}"#.utf8)
        let response = try JSONDecoder().decode(WhisperBootstrapResponse.self, from: data)

        #expect(response.ok)
        #expect(response.messages[.couple]?.first?.clientId == "client_fixture_001")
    }

    @Test("retained endpoint paths do not drift")
    func endpointPaths() {
        #expect(WhisperAPIEndpoint.login.path == "/api/v2/login")
        #expect(WhisperAPIEndpoint.bootstrap.path == "/api/bootstrap")
        #expect(WhisperAPIEndpoint.sync(cursor: nil, limit: 100).path == "/api/v2/sync")
        #expect(WhisperAPIEndpoint.syncAck.path == "/api/v2/sync/ack")
        #expect(WhisperAPIEndpoint.upload(purpose: .message).queryItems.first?.value == "message")
    }

    @Test("message pagination keeps exactly one direction")
    func messagePaginationQuery() {
        let endpoint = WhisperAPIEndpoint.messages(
            channel: .couple,
            since: nil,
            after: nil,
            before: 1_700_000_000_000,
            around: nil,
            limit: 60
        )
        let values = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })

        #expect(values["channel"] == "couple")
        #expect(values["before"] == "1700000000000")
        #expect(values["limit"] == "60")
        #expect(values["after"] == nil)
    }

    @Test("socket event names remain server-compatible")
    func socketEventNames() {
        #expect(WhisperSocketEvent.messageSend.rawValue == "message:send")
        #expect(WhisperSocketEvent.messageRecalled.rawValue == "message:recalled")
        #expect(WhisperSocketEvent.sharedSet.rawValue == "shared:set")
    }

    @Test("socket token stays in the CONNECT auth payload")
    func socketAuthenticationPayload() {
        let authentication = WhisperSocketAuthentication(token: "fixture-token-not-valid")

        #expect(authentication.payload == ["token": "fixture-token-not-valid"])
    }

    @Test("bootstrap refuses to run before login establishes a token")
    func bootstrapRequiresToken() async throws {
        let baseURL = try #require(URL(string: "https://example.invalid"))
        let transport = WhisperStubHTTPClient(responses: [:])
        let api = WhisperAPIClient(
            transport: transport,
            configuration: WhisperAPIConfiguration(baseURL: baseURL)
        )

        do {
            _ = try await api.bootstrap()
            Issue.record("Bootstrap unexpectedly ran without a token")
        } catch let error as WhisperAPIError {
            #expect(error == .missingToken)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let requests = await transport.requests()
        #expect(requests.isEmpty)
    }

    @Test("send ack is authoritative and carries the client id")
    func sendAckDecoding() throws {
        let data = Data(#"{"ok":true,"message":{"id":"msg_fixture_003","sender":"xu","senderName":"小旭","kind":"user","type":"text","text":"fixture send","url":null,"replyTo":null,"replyPreview":null,"reply":null,"meta":null,"attachments":null,"recalledText":null,"channel":"couple","ts":1700000002000,"clientId":"client_fixture_send_001"}}"#.utf8)
        let ack = try JSONDecoder().decode(WhisperMessageSendAck.self, from: data)

        #expect(ack.ok)
        #expect(ack.message.clientId == "client_fixture_send_001")
    }
}
