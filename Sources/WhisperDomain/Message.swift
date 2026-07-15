import Foundation

public enum WhisperChannel: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case couple
    case ai
}

public enum WhisperMessageType: String, Codable, Equatable, Sendable {
    case text
    case image
    case video
    case sticker
    case voice
    case file
}

public struct WhisperAttachment: Codable, Equatable, Sendable {
    public let assetId: String
    public let role: String
    public let uploadId: String?
    public let order: Int

    public init(assetId: String, role: String, uploadId: String? = nil, order: Int = 0) {
        self.assetId = assetId
        self.role = role
        self.uploadId = uploadId
        self.order = order
    }
}

public struct WhisperMessage: Codable, Equatable, Sendable {
    public let id: String
    public let sender: String
    public let senderName: String?
    public let kind: String?
    public let type: WhisperMessageType
    public let text: String?
    public let url: String?
    public let replyTo: String?
    public let replyPreview: String?
    public let reply: WhisperJSONValue?
    public let meta: WhisperJSONValue?
    public let attachments: [WhisperAttachment]?
    public let recalledText: String?
    public let channel: WhisperChannel
    public let ts: Int64
    public let clientId: String?

    public init(
        id: String,
        sender: String,
        senderName: String? = nil,
        kind: String? = nil,
        type: WhisperMessageType,
        text: String? = nil,
        url: String? = nil,
        replyTo: String? = nil,
        replyPreview: String? = nil,
        reply: WhisperJSONValue? = nil,
        meta: WhisperJSONValue? = nil,
        attachments: [WhisperAttachment]? = nil,
        recalledText: String? = nil,
        channel: WhisperChannel,
        ts: Int64,
        clientId: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.senderName = senderName
        self.kind = kind
        self.type = type
        self.text = text
        self.url = url
        self.replyTo = replyTo
        self.replyPreview = replyPreview
        self.reply = reply
        self.meta = meta
        self.attachments = attachments
        self.recalledText = recalledText
        self.channel = channel
        self.ts = ts
        self.clientId = clientId
    }
}

public struct WhisperMessageSend: Codable, Equatable, Sendable {
    public let channel: WhisperChannel
    public let type: WhisperMessageType
    public let text: String?
    public let url: String?
    public let uploadId: String?
    public let replyTo: String?
    public let replyPreview: String?
    public let attachments: [WhisperAttachment]?
    public let meta: WhisperJSONValue?
    public let clientId: String

    public init(
        channel: WhisperChannel,
        type: WhisperMessageType,
        text: String? = nil,
        url: String? = nil,
        uploadId: String? = nil,
        replyTo: String? = nil,
        replyPreview: String? = nil,
        attachments: [WhisperAttachment]? = nil,
        meta: WhisperJSONValue? = nil,
        clientId: String
    ) {
        self.channel = channel
        self.type = type
        self.text = text
        self.url = url
        self.uploadId = uploadId
        self.replyTo = replyTo
        self.replyPreview = replyPreview
        self.attachments = attachments
        self.meta = meta
        self.clientId = clientId
    }
}

public struct WhisperMessageSendAck: Codable, Equatable, Sendable {
    public let ok: Bool
    public let message: WhisperMessage
}
