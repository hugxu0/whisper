import Foundation

public enum WhisperHTTPMethod: String, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct WhisperHTTPRequest: Equatable, Sendable {
    public let method: WhisperHTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?

    public init(
        method: WhisperHTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }

    public var routeKey: String {
        "\(method.rawValue) \(url.path)"
    }
}

public struct WhisperHTTPResponse: Equatable, Sendable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data = Data()) {
        self.statusCode = statusCode
        self.data = data
    }
}

public enum WhisperHTTPClientError: Error, Equatable, Sendable {
    case invalidResponse
}

public protocol WhisperHTTPClient: Sendable {
    func send(_ request: WhisperHTTPRequest) async throws -> WhisperHTTPResponse
}

/// The production HTTP boundary. It has no API knowledge; endpoint and DTO
/// decisions stay in `WhisperAPIClient`.
public actor WhisperURLSessionHTTPClient: WhisperHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: WhisperHTTPRequest) async throws -> WhisperHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw WhisperHTTPClientError.invalidResponse
        }
        return WhisperHTTPResponse(statusCode: response.statusCode, data: data)
    }
}
