#if canImport(SwiftUI)
import SwiftUI

struct WhisperChatBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WhisperVisualTheme.chatBlush,
                    WhisperVisualTheme.chatLavender,
                    WhisperVisualTheme.chatButter
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WhisperVisualTheme.pink.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: 150, y: -290)

            Circle()
                .fill(Color.white.opacity(0.58))
                .frame(width: 230, height: 230)
                .blur(radius: 44)
                .offset(x: -170, y: 180)

            Circle()
                .fill(WhisperVisualTheme.chatButter.opacity(0.72))
                .frame(width: 260, height: 260)
                .blur(radius: 58)
                .offset(x: 140, y: 380)
        }
        .ignoresSafeArea()
    }
}

struct WhisperChatTopBar: View {
    let title: String
    let status: String
    let statusColor: Color
    let onBack: () -> Void
    let onMore: () -> Void

    var body: some View {
        glassGroup
            .padding(.horizontal, 14)
            .padding(.top, 7)
            .padding(.bottom, 11)
            .background(WhisperChatChromeFade(edge: .top))
    }

    @ViewBuilder
    private var glassGroup: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                controls
            }
        } else {
            controls
        }
        #else
        controls
        #endif
    }

    private var controls: some View {
        HStack(spacing: 12) {
            WhisperGlassIconButton(
                systemName: "chevron.left",
                accessibilityLabel: "返回",
                action: onBack
            )

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(WhisperVisualTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .whisperGlass(
                in: Capsule(),
                tint: WhisperVisualTheme.chatRose.opacity(0.05)
            )
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            WhisperGlassIconButton(
                systemName: "ellipsis",
                tint: WhisperVisualTheme.chatRose,
                accessibilityLabel: "更多",
                action: onMore
            )
        }
    }
}

struct WhisperChatComposer: View {
    @Binding var draft: String
    @FocusState.Binding var focused: Bool

    let isSending: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onAccessory: () -> Void
    let onReconnect: (() -> Void)?

    var body: some View {
        VStack(spacing: 7) {
            if let onReconnect {
                Button(action: onReconnect) {
                    Label("连接已断开，点此重连", systemImage: "wifi.exclamationmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .whisperGlass(in: Capsule(), tint: Color.red.opacity(0.06), interactive: true)
            }

            glassGroup
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(WhisperChatChromeFade(edge: .bottom))
    }

    @ViewBuilder
    private var glassGroup: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                controls
            }
        } else {
            controls
        }
        #else
        controls
        #endif
    }

    private var controls: some View {
        HStack(alignment: .bottom, spacing: 9) {
            WhisperGlassIconButton(
                systemName: "pawprint.fill",
                tint: WhisperVisualTheme.chatRose,
                accessibilityLabel: "大橘",
                action: onAccessory
            )

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: onAccessory) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 30, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(WhisperVisualTheme.mutedInk)
                .accessibilityLabel("添加附件")

                TextField("输入消息", text: $draft, axis: .vertical)
                    .focused($focused)
                    .lineLimit(1...5)
                    .font(.body)
                    .foregroundStyle(WhisperVisualTheme.ink)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend { onSend() }
                    }
                    .padding(.vertical, 9)
                    .accessibilityIdentifier("whisper.chat.composer")

                Button(action: onAccessory) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 30, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(WhisperVisualTheme.mutedInk)
                .accessibilityLabel("表情")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .whisperGlass(
                in: RoundedRectangle(cornerRadius: 25, style: .continuous),
                tint: Color.white.opacity(0.08)
            )

            WhisperGlassIconButton(
                systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "mic.fill"
                    : "arrow.up",
                tint: WhisperVisualTheme.chatRose,
                isEnabled: isSending == false,
                accessibilityLabel: canSend ? "发送消息" : "语音",
                action: canSend ? onSend : onAccessory
            )
            .accessibilityIdentifier("whisper.chat.send")
        }
    }
}

private struct WhisperGlassIconButton: View {
    let systemName: String
    var tint: Color = WhisperVisualTheme.ink
    var isEnabled = true
    let accessibilityLabel: String
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.glass)
            .tint(tint)
            .disabled(isEnabled == false)
            .accessibilityLabel(accessibilityLabel)
        } else {
            fallbackButton
        }
        #else
        fallbackButton
        #endif
    }

    private var fallbackButton: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .whisperGlass(in: Circle(), tint: tint.opacity(0.06), interactive: true)
        .disabled(isEnabled == false)
        .accessibilityLabel(accessibilityLabel)
    }

    private var label: some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }
}

private struct WhisperChatChromeFade: View {
    enum Edge: Equatable {
        case top
        case bottom
    }

    let edge: Edge

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    WhisperVisualTheme.chatBlush.opacity(0.56),
                    WhisperVisualTheme.chatLavender.opacity(0.22),
                    .clear
                ],
                startPoint: edge == .top ? .top : .bottom,
                endPoint: edge == .top ? .bottom : .top
            )
        }
        .mask(
            LinearGradient(
                colors: [.black, .black.opacity(0.88), .clear],
                startPoint: edge == .top ? .top : .bottom,
                endPoint: edge == .top ? .bottom : .top
            )
        )
        .ignoresSafeArea()
    }
}
#endif
