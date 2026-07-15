#if canImport(SwiftUI)
import SwiftUI
import PhotosUI

enum WhisperChatAccessoryMode: Equatable {
    case interactions
    case attachments
    case emoji
}

struct WhisperChatAccessoryPanel: View {
    let mode: WhisperChatAccessoryMode
    let onEmoji: (String) -> Void
    let onInteraction: (String) -> Void
    let onFile: () -> Void
    @Binding var mediaSelection: PhotosPickerItem?
    @Binding var stickerSelection: PhotosPickerItem?

    private let emojis = Array("😀🥰😘😍🥹😂🤣😊😴😭😤🤗🤭🫶❤️💕💗💖🌹🌸🐶🐱✨🎉👍🏻")
    private let interactions = ["💗 想你了", "🖐️ 拍一拍", "🌸 送你一朵花花", "💩 扔了个粑粑", "📝 给你贴了一张小纸条"]

    var body: some View {
        Group {
            switch mode {
            case .emoji:
                emojiGrid
            case .interactions:
                interactionGrid
            case .attachments:
                attachmentGrid
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .whisperGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { _, emoji in
                Button { onEmoji(String(emoji)) } label: {
                    Text(String(emoji))
                        .font(.system(size: 27))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("插入表情 \(String(emoji))")
            }
        }
    }

    private var interactionGrid: some View {
        VStack(spacing: 8) {
            ForEach(interactions, id: \.self) { interaction in
                Button { onInteraction(interaction) } label: {
                    Text(interaction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WhisperVisualTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.52), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var attachmentGrid: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $mediaSelection, matching: .any(of: [.images, .videos])) {
                WhisperAttachmentTile(icon: "photo.on.rectangle.angled", title: "照片/视频")
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $stickerSelection, matching: .images) {
                WhisperAttachmentTile(icon: "face.smiling", title: "图片表情")
            }
            .buttonStyle(.plain)

            Button(action: onFile) {
                WhisperAttachmentTile(icon: "doc.fill", title: "文件")
            }
            .buttonStyle(.plain)
        }
    }

}

private struct WhisperAttachmentTile: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(WhisperVisualTheme.chatRose)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WhisperVisualTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
    }
}
#endif
