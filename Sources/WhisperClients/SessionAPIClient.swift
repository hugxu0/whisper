import Foundation
import WhisperDomain

public enum WhisperAPIError: Error, Equatable, Sendable {
    case missingToken
    case server(statusCode: Int, message: String?)
    case decoding
}

public protocol WhisperSessionAPI: Sendable {
    func login(_ request: WhisperLoginRequest) async throws -> WhisperLoginResponse
    func bootstrap() async throws -> WhisperBootstrapResponse
}

/// API-aware client. Authentication state lives here, not in a global store or
/// in a View. The server's paths and JSON shapes remain explicit at this edge.
public actor WhisperAPIClient: WhisperSessionAPI {
    private let transport: any WhisperHTTPClient
    private let configuration: WhisperAPIConfiguration
    private var token: String?

    public init(
        transport: any WhisperHTTPClient,
        configuration: WhisperAPIConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
        self.token = configuration.bearerToken
    }

    public func login(_ request: WhisperLoginRequest) async throws -> WhisperLoginResponse {
        let body = try JSONEncoder().encode(request)
        let result: WhisperLoginResponse = try await send(
            endpoint: .login,
            method: .post,
            body: body,
            requiresToken: false
        )
        token = result.token
        return result
    }

    public func bootstrap() async throws -> WhisperBootstrapResponse {
        guard token != nil else { throw WhisperAPIError.missingToken }
        return try await send(endpoint: .bootstrap, method: .get, requiresToken: true)
    }

    public func clearToken() {
        token = nil
    }

    private func send<Response: Decodable>(
        endpoint: WhisperAPIEndpoint,
        method: WhisperHTTPMethod,
        body: Data? = nil,
        requiresToken: Bool
    ) async throws -> Response {
        let url = try makeURL(for: endpoint)
        var headers = ["Accept": "application/json"]
        if body != nil {
            headers["Content-Type"] = "application/json"
        }
        if requiresToken, let token {
            headers["Authorization"] = "Bearer \(token)"
        }

        let response = try await transport.send(
            WhisperHTTPRequest(method: method, url: url, headers: headers, body: body)
        )
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(WhisperServerError.self, from: response.data))?.error
            throw WhisperAPIError.server(statusCode: response.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: response.data)
        } catch {
            throw WhisperAPIError.decoding
        }
    }

    private func makeURL(for endpoint: WhisperAPIEndpoint) throws -> URL {
        guard var components = URLComponents(
            url: configuration.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw WhisperAPIError.decoding
        }
        components.path = endpoint.path
        components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
        guard let url = components.url else { throw WhisperAPIError.decoding }
        return url
    }
}

private struct WhisperServerError: Decodable {
    let error: String
}
