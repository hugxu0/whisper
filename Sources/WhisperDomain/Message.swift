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
    public let id: String?
    public let assetId: String
    public let role: String
    public let uploadId: String?
    public let order: Int
    public let url: String?
    public let mimeType: String?
    public let size: Int?

    public init(
        id: String? = nil,
        assetId: String,
        role: String,
        uploadId: String? = nil,
        order: Int = 0,
        url: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil
    ) {
        self.id = id
        self.assetId = assetId
        self.role = role
        self.uploadId = uploadId
        self.order = order
        self.url = url
        self.mimeType = mimeType
        self.size = size
    }
}

public struct WhisperVoiceTranscript: Codable, Equatable, Sendable {
    public let status: String
    public let text: String
    public let rawText: String?
    public let corrected: Bool
    public let language: String?
    public let version: Int

    public init(
        status: String,
        text: String,
        rawText: String? = nil,
        corrected: Bool = false,
        language: String? = nil,
        version: Int = 0
    ) {
        self.status = status
        self.text = text
        self.rawText = rawText
        self.corrected = corrected
        self.language = language
        self.version = version
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
    public let transcript: WhisperVoiceTranscript?

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
        clientId: String? = nil,
        transcript: WhisperVoiceTranscript? = nil
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
        self.transcript = transcript
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

    public init(ok: Bool, message: WhisperMessage) {
        self.ok = ok
        self.message = message
    }
}

public struct WhisperRecallAcknowledgement: Codable, Equatable, Sendable {
    public let ok: Bool
    public let notice: WhisperMessage?

    public init(ok: Bool, notice: WhisperMessage? = nil) {
        self.ok = ok
        self.notice = notice
    }
}

public struct WhisperSearchAcknowledgement: Codable, Equatable, Sendable {
    public let ok: Bool
    public let list: [WhisperMessage]

    public init(ok: Bool, list: [WhisperMessage]) {
        self.ok = ok
        self.list = list
    }
}

public struct WhisperMessageRecalledEvent: Codable, Equatable, Sendable {
    public let id: String
    public let channel: WhisperChannel
    public let by: String?
    public let byName: String?
    public let deleted: Bool?
    public let notice: WhisperMessage?
    public let syncCursor: Int64?

    public init(
        id: String,
        channel: WhisperChannel,
        by: String? = nil,
        byName: String? = nil,
        deleted: Bool? = nil,
        notice: WhisperMessage? = nil,
        syncCursor: Int64? = nil
    ) {
        self.id = id
        self.channel = channel
        self.by = by
        self.byName = byName
        self.deleted = deleted
        self.notice = notice
        self.syncCursor = syncCursor
    }
}

public struct WhisperReadUpdate: Codable, Equatable, Sendable {
    public let channel: WhisperChannel
    public let user: String
    public let ts: Int64

    public init(channel: WhisperChannel, user: String, ts: Int64) {
        self.channel = channel
        self.user = user
        self.ts = ts
    }
}
