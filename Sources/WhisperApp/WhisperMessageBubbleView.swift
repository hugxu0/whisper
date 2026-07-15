#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

struct WhisperMessageBubbleRow: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let entry: WhisperChatEntry
    let isOutgoing: Bool
    let isRead: Bool
    let account: WhisperAccount
    let onRetry: () -> Void
    let onReply: () -> Void
    let onRecall: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if isOutgoing {
                Spacer(minLength: WhisperChatMetrics.avatarRailWidth)
            } else {
                avatarRail
            }

            messageColumn
                .frame(maxWidth: maximumBubbleWidth, alignment: isOutgoing ? .trailing : .leading)

            if isOutgoing {
                WhisperDeliveryBadge(
                    delivery: entry.delivery,
                    isRead: isRead,
                    onRetry: onRetry
                )
                .frame(width: WhisperChatMetrics.deliveryRailWidth)
                avatarRail
            } else {
                Spacer(minLength: WhisperChatMetrics.avatarRailWidth + WhisperChatMetrics.deliveryRailWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
        .contextMenu {
            Button(action: onReply) {
                Label("回复", systemImage: "arrowshape.turn.up.left")
            }
            if isOutgoing, case .sent = entry.delivery {
                Button(role: .destructive, action: onRecall) {
                    Label("撤回", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .accessibilityIdentifier("whisper.chat.message.\(entry.id)")
    }

    private var messageColumn: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
            if let replyPreview = entry.message.replyPreview, replyPreview.isEmpty == false {
                Text(replyPreview)
                    .font(.caption)
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
                    .lineLimit(2)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 12))
            }

            WhisperMessageBody(message: entry.message, isOutgoing: isOutgoing)

            Text(timestamp, format: .dateTime.hour().minute())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(WhisperVisualTheme.mutedInk.opacity(0.72))
                .padding(.horizontal, 4)
        }
    }

    private var avatarRail: some View {
        WhisperAvatarView(
            urlString: account.avatar,
            fallback: account.username == "xu" ? "🐶" : "🐱",
            size: WhisperChatMetrics.avatarSize,
            ring: isOutgoing ? WhisperVisualTheme.softPink : Color.white
        )
        .frame(width: WhisperChatMetrics.avatarRailWidth)
    }

    private var maximumBubbleWidth: CGFloat {
        horizontalSizeClass == .regular ? 430 : 276
    }

    private var timestamp: Date {
        let raw = Double(entry.message.ts)
        return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
    }
}

struct WhisperMessageBody: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let message: WhisperMessage
    let isOutgoing: Bool

    @State private var selectedMedia: WhisperPresentedMedia?

    private var presentation: WhisperMessagePresentation {
        WhisperMessagePresentation(message: message)
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch presentation.kind {
            case .text:
                textBubble(presentation.text)
            case .emoji:
                Text(presentation.text)
                    .font(.system(size: presentation.text.count <= 3 ? 46 : 34))
                    .padding(.horizontal, 3)
                    .accessibilityLabel(presentation.text)
            case .image:
                imageContent
            case .sticker:
                stickerContent
            case .video:
                actionableMediaCard(icon: "play.circle.fill", title: "视频", subtitle: presentation.text)
            case .voice:
                Button(action: selectFirstMedia) { voiceCard }
                    .buttonStyle(.plain)
            case .file:
                actionableMediaCard(icon: "doc.fill", title: presentation.previewText, subtitle: "文件消息")
            case .recalled:
                recalledBubble
            case .unsupported:
                mediaCard(icon: "questionmark.square.dashed", title: "不支持的消息", subtitle: "请更新客户端")
            }
        }
        .sheet(item: $selectedMedia) { media in
            WhisperMediaPreviewView(media: media, kind: presentation.kind)
        }
    }

    private func textBubble(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.ink)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: bubbleShape)
            .overlay(bubbleShape.stroke(Color.white.opacity(isOutgoing ? 0.20 : 0.72), lineWidth: 1))
            .shadow(color: bubbleShadowColor, radius: 7, y: 3)
    }

    private var imageContent: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 7) {
            if presentation.media.isEmpty {
                mediaPlaceholder(icon: "photo.badge.exclamationmark", title: "图片不可用")
            } else if presentation.media.count == 1, let media = presentation.media.first {
                remoteImage(media, sticker: false)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(presentation.media.filter { $0.role != "pairedVideo" }) { media in
                        remoteImage(media, sticker: false)
                            .frame(width: multiImageSide, height: multiImageSide)
                    }
                }
            }
            if presentation.text.isEmpty == false, presentation.text != "[图片]" {
                textBubble(presentation.text)
            }
        }
    }

    private var stickerContent: some View {
        Group {
            if let media = presentation.media.first {
                remoteImage(media, sticker: true)
            } else {
                mediaPlaceholder(icon: "face.smiling", title: "表情暂不可用")
                    .frame(width: 150, height: 112)
            }
        }
        .accessibilityLabel("表情包")
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "waveform")
                    .font(.system(size: 21, weight: .medium))
                Text("语音")
                    .font(.subheadline.weight(.semibold))
            }
            if let transcript = presentation.transcript, transcript.text.isEmpty == false {
                Divider().overlay(isOutgoing ? Color.white.opacity(0.3) : Color.black.opacity(0.08))
                Text(transcript.text)
                    .font(.caption)
                    .lineLimit(4)
            }
        }
        .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.ink)
        .padding(13)
        .frame(minWidth: 176, alignment: .leading)
        .background(bubbleBackground, in: bubbleShape)
    }

    private func mediaCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.chatRose)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                if subtitle.isEmpty == false, subtitle != title {
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(2)
                        .opacity(0.72)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.ink)
        .padding(14)
        .frame(width: horizontalSizeClass == .regular ? 280 : 220)
        .background(bubbleBackground, in: bubbleShape)
    }

    private func remoteImage(_ media: WhisperPresentedMedia, sticker: Bool) -> some View {
        Button {
            selectedMedia = media
        } label: {
            AsyncImage(url: resolvedURL(media.url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    mediaPlaceholder(
                        icon: sticker ? "face.smiling" : "photo.badge.exclamationmark",
                        title: sticker ? "表情加载失败" : "图片加载失败"
                    )
                default:
                    ZStack {
                        Color.white.opacity(0.52)
                        ProgressView().tint(WhisperVisualTheme.chatRose)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(
            width: sticker ? stickerSide : mediaWidth,
            height: sticker ? stickerSide : mediaHeight
        )
        .background(Color.white.opacity(sticker ? 0.18 : 0.55))
        .clipShape(RoundedRectangle(cornerRadius: sticker ? 14 : WhisperChatMetrics.mediaCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: sticker ? 14 : WhisperChatMetrics.mediaCornerRadius)
                .stroke(Color.white.opacity(sticker ? 0.22 : 0.76), lineWidth: sticker ? 0.5 : 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 8, y: 4)
    }

    private func actionableMediaCard(icon: String, title: String, subtitle: String) -> some View {
        Button(action: selectFirstMedia) {
            mediaCard(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func selectFirstMedia() {
        selectedMedia = presentation.media.first
    }

    private func mediaPlaceholder(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 29))
            Text(title).font(.caption.weight(.semibold))
        }
        .foregroundStyle(WhisperVisualTheme.mutedInk)
        .frame(width: mediaWidth, height: mediaHeight)
        .background(Color.white.opacity(0.64))
    }

    private var recalledBubble: some View {
        Label(presentation.previewText, systemImage: "arrow.uturn.backward")
            .font(.caption)
            .foregroundStyle(WhisperVisualTheme.mutedInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.58), in: Capsule())
    }

    private func resolvedURL(_ rawValue: String) -> URL? {
        if let url = URL(string: rawValue), url.scheme != nil { return url }
        guard let baseURL = URL(string: "https://hoo66.top") else { return nil }
        return URL(string: rawValue, relativeTo: baseURL)?.absoluteURL
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WhisperChatMetrics.bubbleCornerRadius, style: .continuous)
    }

    private var bubbleBackground: AnyShapeStyle {
        isOutgoing
            ? AnyShapeStyle(WhisperVisualTheme.primaryGradient)
            : AnyShapeStyle(Color.white.opacity(0.90))
    }

    private var bubbleShadowColor: Color {
        isOutgoing ? WhisperVisualTheme.chatRose.opacity(0.16) : Color.black.opacity(0.05)
    }

    private var mediaWidth: CGFloat { horizontalSizeClass == .regular ? 320 : 230 }
    private var mediaHeight: CGFloat { horizontalSizeClass == .regular ? 260 : 205 }
    private var multiImageSide: CGFloat { horizontalSizeClass == .regular ? 154 : 112 }
    private var stickerSide: CGFloat { horizontalSizeClass == .regular ? 210 : 166 }
}

struct WhisperDeliveryBadge: View {
    let delivery: WhisperMessageDeliveryState
    let isRead: Bool
    let onRetry: () -> Void

    var body: some View {
        switch delivery {
        case .sent:
            badge(systemName: isRead ? "checkmark.circle.fill" : "checkmark", color: WhisperVisualTheme.chatRose)
                .accessibilityLabel(isRead ? "已读" : "已发送")
        case .sending:
            badge(systemName: "clock", color: WhisperVisualTheme.mutedInk)
                .accessibilityLabel("发送中")
        case .uploading(let progress):
            ZStack {
                Circle().fill(WhisperVisualTheme.mutedInk)
                if let progress {
                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(3)
                } else {
                    ProgressView().controlSize(.mini).tint(.white)
                }
            }
            .frame(width: 21, height: 21)
            .accessibilityLabel("正在上传")
        case .failed:
            Button(action: onRetry) {
                badge(systemName: "exclamationmark", color: .red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("发送失败，点按重试")
        }
    }

    private func badge(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 21, height: 21)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.84), lineWidth: 1))
    }
}
#endif
