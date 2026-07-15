import Foundation

public struct WhisperSyncEvent: Codable, Equatable, Sendable {
    public let seq: Int64
    public let entityType: String
    public let entityId: String
    public let operation: String
    public let version: Int
    public let payload: WhisperJSONValue
    public let createdAt: Int64

    public init(
        seq: Int64,
        entityType: String,
        entityId: String,
        operation: String,
        version: Int,
        payload: WhisperJSONValue,
        createdAt: Int64
    ) {
        self.seq = seq
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.version = version
        self.payload = payload
        self.createdAt = createdAt
    }
}

public struct WhisperSyncPage: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let events: [WhisperSyncEvent]
    public let nextCursor: Int64
    public let hasMore: Bool

    public init(
        protocolVersion: Int,
        events: [WhisperSyncEvent],
        nextCursor: Int64,
        hasMore: Bool
    ) {
        self.protocolVersion = protocolVersion
        self.events = events
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public struct WhisperMessagePage: Codable, Equatable, Sendable {
    public let ok: Bool
    public let list: [WhisperMessage]
    public let total: Int

    public init(ok: Bool, list: [WhisperMessage], total: Int) {
        self.ok = ok
        self.list = list
        self.total = total
    }
}

public struct WhisperUploadResult: Codable, Equatable, Sendable {
    public let id: String
    public let url: String
    public let mimeType: String
    public let size: Int
    public let type: String

    public init(id: String, url: String, mimeType: String, size: Int, type: String) {
        self.id = id
        self.url = url
        self.mimeType = mimeType
        self.size = size
        self.type = type
    }
}
