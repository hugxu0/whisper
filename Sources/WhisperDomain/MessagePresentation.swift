import Foundation

public enum WhisperMessagePresentationKind: String, Equatable, Sendable {
    case text
    case emoji
    case image
    case video
    case sticker
    case voice
    case file
    case recalled
    case unsupported
}

public struct WhisperPresentedMedia: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: String
    public let mimeType: String?
    public let role: String?

    public init(id: String, url: String, mimeType: String? = nil, role: String? = nil) {
        self.id = id
        self.url = url
        self.mimeType = mimeType
        self.role = role
    }
}

public struct WhisperMessagePresentation: Equatable, Sendable {
    public let kind: WhisperMessagePresentationKind
    public let text: String
    public let media: [WhisperPresentedMedia]
    public let transcript: WhisperVoiceTranscript?

    public init(message: WhisperMessage) {
        let normalizedText = (message.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let media = Self.media(from: message)

        if message.recalledText != nil {
            self.kind = .recalled
            self.text = message.recalledText.flatMap { $0.isEmpty ? nil : $0 } ?? "消息已撤回"
            self.media = []
            self.transcript = nil
            return
        }

        switch message.type {
        case .text:
            if normalizedText == "[表情]" {
                self.kind = .sticker
            } else if Self.isEmojiOnly(normalizedText) {
                self.kind = .emoji
            } else {
                self.kind = .text
            }
        case .image:
            self.kind = .image
        case .video:
            self.kind = .video
        case .sticker:
            self.kind = .sticker
        case .voice:
            self.kind = .voice
        case .file:
            self.kind = .file
        }

        self.text = normalizedText
        self.media = media
        self.transcript = message.transcript
    }

    public var previewText: String {
        switch kind {
        case .text, .emoji:
            return text
        case .image:
            return text.isEmpty ? "[图片]" : text
        case .video:
            return text.isEmpty ? "[视频]" : text
        case .sticker:
            return "[表情]"
        case .voice:
            return transcript?.text.isEmpty == false ? transcript?.text ?? "[语音]" : "[语音]"
        case .file:
            return text.isEmpty ? "[文件]" : text
        case .recalled:
            return text.isEmpty ? "消息已撤回" : text
        case .unsupported:
            return "[不支持的消息]"
        }
    }

    private static func media(from message: WhisperMessage) -> [WhisperPresentedMedia] {
        let attachments = (message.attachments ?? [])
            .filter { $0.role == "photo" || $0.role == "pairedVideo" }
            .sorted { $0.order < $1.order }
            .compactMap { attachment -> WhisperPresentedMedia? in
                guard let url = attachment.url, url.isEmpty == false else { return nil }
                return WhisperPresentedMedia(
                    id: attachment.id ?? "\(attachment.assetId):\(attachment.role):\(attachment.order)",
                    url: url,
                    mimeType: attachment.mimeType,
                    role: attachment.role
                )
            }

        if attachments.isEmpty == false {
            return attachments
        }
        guard let url = message.url, url.isEmpty == false else { return [] }
        return [WhisperPresentedMedia(id: message.id, url: url)]
    }

    private static func isEmojiOnly(_ value: String) -> Bool {
        let characters = value.filter { $0.isWhitespace == false }
        guard characters.isEmpty == false, characters.count <= 12 else { return false }
        return characters.allSatisfy { character in
            character.unicodeScalars.contains { scalar in
                scalar.properties.isEmojiPresentation
                    || (scalar.properties.isEmoji && scalar.value >= 0x203C)
            }
        }
    }
}
