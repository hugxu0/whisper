#if canImport(SwiftUI)
import Foundation
import SwiftUI
import WhisperDomain
import WhisperFeatures

struct WhisperChatTimelineView: View {
    let entries: [WhisperChatEntry]
    let currentUsername: String?
    let currentAccount: WhisperAccount
    let partnerAccount: WhisperAccount
    let composerFocused: Bool
    let onRetry: (String) -> Void

    private let bottomAnchorID = "whisper.chat.timeline.bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 9) {
                    if entries.isEmpty {
                        emptyState
                    }

                    ForEach(entries) { entry in
                        let outgoing = entry.message.sender == currentUsername
                        WhisperMessageBubbleRow(
                            entry: entry,
                            isOutgoing: outgoing,
                            account: outgoing ? currentAccount : partnerAccount,
                            onRetry: { onRetry(entry.id) }
                        )
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, 11)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .defaultScrollAnchor(.bottom)
            .whisperInteractiveKeyboardDismissal()
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: entries.last?.id) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: composerFocused) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
        }
        .accessibilityIdentifier("whisper.chat.timeline")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(WhisperVisualTheme.chatRose)
            Text("还没有消息")
                .font(.headline)
                .foregroundStyle(WhisperVisualTheme.ink)
            Text("从一句简单的问候开始吧")
                .font(.subheadline)
                .foregroundStyle(WhisperVisualTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.26)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct WhisperMessageBubbleRow: View {
    let entry: WhisperChatEntry
    let isOutgoing: Bool
    let account: WhisperAccount
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if isOutgoing {
                Spacer(minLength: 45)
            } else {
                avatar
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                if let replyPreview = entry.message.replyPreview,
                   replyPreview.isEmpty == false {
                    Text(replyPreview)
                        .font(.caption)
                        .foregroundStyle(WhisperVisualTheme.mutedInk)
                        .lineLimit(2)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.62), in: Capsule())
                }

                WhisperMessageBody(
                    message: entry.message,
                    isOutgoing: isOutgoing
                )

                Text(timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(WhisperVisualTheme.mutedInk.opacity(0.72))
                    .padding(.horizontal, 5)
            }

            if isOutgoing {
                WhisperDeliveryBadge(
                    delivery: entry.delivery,
                    onRetry: onRetry
                )
                avatar
            } else {
                Spacer(minLength: 45)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
        .accessibilityIdentifier("whisper.chat.message.\(entry.id)")
    }

    private var avatar: some View {
        WhisperAvatarView(
            urlString: account.avatar,
            fallback: account.username == "xu" ? "🐶" : "🐱",
            size: 36,
            ring: isOutgoing ? WhisperVisualTheme.softPink : Color.white
        )
    }

    private var timestamp: Date {
        let raw = Double(entry.message.ts)
        let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
        return Date(timeIntervalSince1970: seconds)
    }
}

private struct WhisperMessageBody: View {
    let message: WhisperMessage
    let isOutgoing: Bool

    var body: some View {
        switch message.type {
        case .text:
            textBubble(message.text ?? "")
        case .image, .sticker:
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 7) {
                remoteImage
                if let text = message.text, text.isEmpty == false {
                    textBubble(text)
                }
            }
        case .video:
            mediaCard(
                icon: "play.circle.fill",
                title: "视频",
                subtitle: message.text ?? "点按后可播放"
            )
        case .voice:
            mediaCard(
                icon: "waveform",
                title: "语音消息",
                subtitle: message.text ?? "语音"
            )
        case .file:
            mediaCard(
                icon: "doc.fill",
                title: message.text ?? "文件",
                subtitle: "文件消息"
            )
        }
    }

    private func textBubble(_ text: String) -> some View {
        Text(message.recalledText == nil ? text : "消息已撤回")
            .font(.body)
            .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.ink)
            .multilineTextAlignment(isOutgoing ? .trailing : .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isOutgoing
                    ? AnyShapeStyle(WhisperVisualTheme.primaryGradient)
                    : AnyShapeStyle(Color.white.opacity(0.88)),
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(Color.white.opacity(isOutgoing ? 0.20 : 0.72), lineWidth: 1)
            )
            .shadow(
                color: isOutgoing
                    ? WhisperVisualTheme.chatRose.opacity(0.18)
                    : Color.black.opacity(0.05),
                radius: 8,
                y: 4
            )
    }

    private var remoteImage: some View {
        AsyncImage(url: mediaURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                mediaPlaceholder(icon: "photo.badge.exclamationmark", title: "图片加载失败")
            default:
                ZStack {
                    Color.white.opacity(0.58)
                    ProgressView()
                        .tint(WhisperVisualTheme.chatRose)
                }
            }
        }
        .frame(width: 220, height: 220)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }

    private func mediaCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.chatRose)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .lineLimit(2)
                    .opacity(0.72)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isOutgoing ? Color.white : WhisperVisualTheme.ink)
        .padding(14)
        .frame(width: 220)
        .background(
            isOutgoing
                ? AnyShapeStyle(WhisperVisualTheme.primaryGradient)
                : AnyShapeStyle(Color.white.opacity(0.88)),
            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
        )
    }

    private func mediaPlaceholder(icon: String, title: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 30))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(WhisperVisualTheme.mutedInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.66))
    }

    private var mediaURL: URL? {
        guard let rawValue = message.url,
              rawValue.isEmpty == false
        else { return nil }

        if let absoluteURL = URL(string: rawValue),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        guard let baseURL = URL(string: "https://hoo66.top") else { return nil }
        return URL(string: rawValue, relativeTo: baseURL)?.absoluteURL
    }
}

private struct WhisperDeliveryBadge: View {
    let delivery: WhisperMessageDeliveryState
    let onRetry: () -> Void

    var body: some View {
        switch delivery {
        case .sent:
            badge(systemName: "checkmark", color: WhisperVisualTheme.chatRose)
                .accessibilityLabel("已发送")
        case .sending:
            badge(systemName: "clock", color: WhisperVisualTheme.mutedInk)
                .accessibilityLabel("发送中")
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
            .frame(width: 20, height: 20)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.84), lineWidth: 1))
    }
}
#endif
