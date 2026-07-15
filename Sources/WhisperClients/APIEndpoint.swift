import Foundation
import WhisperDomain

public struct WhisperAPIConfiguration: Sendable, Equatable {
    public let baseURL: URL
    public let bearerToken: String?

    public init(baseURL: URL, bearerToken: String? = nil) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }
}

public enum WhisperUploadPurpose: String, Equatable, Sendable {
    case message
    case avatar
    case sticker
    case album
}

public enum WhisperAPIEndpoint: Equatable, Sendable {
    case live
    case ready
    case health
    case login
    case accounts
    case me
    case bootstrap
    case messages(channel: WhisperChannel, before: Int64?, limit: Int)
    case sync(cursor: Int64?, limit: Int)
    case upload(purpose: WhisperUploadPurpose)

    public var path: String {
        switch self {
        case .live: return "/live"
        case .ready: return "/ready"
        case .health: return "/health"
        case .login: return "/api/v2/login"
        case .accounts: return "/api/accounts"
        case .me: return "/api/me"
        case .bootstrap: return "/api/bootstrap"
        case .messages: return "/api/messages"
        case .sync: return "/api/v2/sync"
        case .upload: return "/api/upload"
        }
    }

    public var queryItems: [URLQueryItem] {
        switch self {
        case .upload(let purpose):
            return [URLQueryItem(name: "purpose", value: purpose.rawValue)]
        default:
            return []
        }
    }
}
