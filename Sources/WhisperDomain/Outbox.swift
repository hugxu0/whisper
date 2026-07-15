import Foundation

public struct WhisperOutboxItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { request.clientId }
    public let message: WhisperMessage
    public let request: WhisperMessageSend
    public let createdAt: Int64

    public init(message: WhisperMessage, request: WhisperMessageSend, createdAt: Int64) {
        self.message = message
        self.request = request
        self.createdAt = createdAt
    }
}
