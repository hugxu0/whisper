import Foundation

public struct WhisperSyncEvent: Codable, Equatable, Sendable {
    public let seq: Int64
    public let entityType: String
    public let entityId: String
    public let operation: String
    public let version: Int
    public let payload: WhisperJSONValue
    public let createdAt: Int64
}

public struct WhisperSyncPage: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let events: [WhisperSyncEvent]
    public let nextCursor: Int64
    public let hasMore: Bool
}

public struct WhisperMessagePage: Codable, Equatable, Sendable {
    public let ok: Bool
    public let list: [WhisperMessage]
    public let total: Int
}

public struct WhisperUploadResult: Codable, Equatable, Sendable {
    public let id: String
    public let url: String
    public let mimeType: String
    public let size: Int
    public let type: String
}
