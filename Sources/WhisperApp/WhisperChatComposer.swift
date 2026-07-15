#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain

struct WhisperChatComposer: View {
    @Binding var draft: String
    @FocusState.Binding var focused: Bool

    let reply: WhisperMessage?
    let isRecording: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onCancelReply: () -> Void
    let onPet: () -> Void
    let onAttachment: () -> Void
    let onEmoji: () -> Void
    let onVoice: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            if let reply {
                replyBar(reply)
            }
            controls
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background(WhisperChatChromeFade(edge: .bottom))
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: WhisperChatMetrics.composerSpacing) {
            WhisperGlassIconButton(
                systemName: "pawprint.fill",
                tint: WhisperVisualTheme.chatRose,
                accessibilityLabel: "快捷互动",
                action: onPet
            )

            inputSurface

            WhisperGlassIconButton(
                systemName: trailingIcon,
                tint: isRecording ? .red : WhisperVisualTheme.chatRose,
                isActive: isRecording,
                accessibilityLabel: canSend ? "发送消息" : (isRecording ? "停止并发送录音" : "录制语音"),
                action: canSend ? onSend : onVoice
            )
            .accessibilityIdentifier("whisper.chat.send")
        }
    }

    private var inputSurface: some View {
        HStack(alignment: .center, spacing: 2) {
            composerIcon(systemName: "paperclip", label: "添加附件", action: onAttachment)

            TextField("输入消息", text: $draft, axis: .vertical)
                .focused($focused)
                .lineLimit(1...5)
                .font(.body)
                .foregroundStyle(WhisperVisualTheme.ink)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }
                .padding(.vertical, 12)
                .accessibilityIdentifier("whisper.chat.composer")

            composerIcon(systemName: "face.smiling", label: "表情", action: onEmoji)
        }
        .padding(.horizontal, 4)
        .frame(minHeight: WhisperChatMetrics.composerControlHeight)
        .whisperGlass(
            in: RoundedRectangle(
                cornerRadius: WhisperChatMetrics.composerControlHeight / 2,
                style: .continuous
            ),
            tint: Color.white.opacity(0.08)
        )
    }

    private func composerIcon(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(WhisperVisualTheme.mutedInk)
                .frame(
                    width: WhisperChatMetrics.composerIconHitSize,
                    height: WhisperChatMetrics.composerIconHitSize,
                    alignment: .center
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func replyBar(_ message: WhisperMessage) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(WhisperVisualTheme.chatRose)
                .frame(width: 3, height: 30)
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text("回复 \(message.senderName ?? message.sender)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WhisperVisualTheme.chatRose)
                Text(WhisperMessagePresentation(message: message).previewText)
                    .font(.caption)
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: onCancelReply) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("取消回复")
        }
        .padding(.leading, 13)
        .padding(.trailing, 4)
        .frame(minHeight: 48)
        .whisperGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var trailingIcon: String {
        if canSend { return "arrow.up" }
        return isRecording ? "stop.fill" : "mic.fill"
    }
}
#endif
