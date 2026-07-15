#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

private struct WhisperHomeQuickAction: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let message: String
    let color: Color
}

@MainActor
public struct WhisperChatHomeView: View {
    @State private var controller: WhisperChatController
    @State private var pendingQuickActionID: String?

    private let currentAccount: WhisperAccount
    private let partnerAccount: WhisperAccount
    private let connection: WhisperConnectionState
    private let onOpenChat: () -> Void
    private let onReconnect: () -> Void

    private let quickActions: [WhisperHomeQuickAction] = [
        .init(id: "miss", emoji: "💗", title: "想你了", message: "💗 想你了", color: Color(red: 1.00, green: 0.87, blue: 0.93)),
        .init(id: "pat", emoji: "🖐️", title: "拍一拍", message: "🖐️ 拍一拍", color: Color(red: 1.00, green: 0.91, blue: 0.78)),
        .init(id: "flower", emoji: "🌸", title: "送花花", message: "🌸 送你一朵花花", color: Color(red: 1.00, green: 0.86, blue: 0.93)),
        .init(id: "poop", emoji: "💩", title: "扔粑粑", message: "💩 扔了个粑粑", color: Color(red: 0.96, green: 0.89, blue: 0.78)),
        .init(id: "note", emoji: "🪧", title: "贴条", message: "🪧 给你贴了一张小纸条", color: Color(red: 0.91, green: 0.94, blue: 0.98))
    ]

    public init(
        controller: WhisperChatController,
        currentAccount: WhisperAccount,
        partnerAccount: WhisperAccount,
        connection: WhisperConnectionState,
        onOpenChat: @escaping () -> Void,
        onReconnect: @escaping () -> Void
    ) {
        _controller = State(initialValue: controller)
        self.currentAccount = currentAccount
        self.partnerAccount = partnerAccount
        self.connection = connection
        self.onOpenChat = onOpenChat
        self.onReconnect = onReconnect
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                homePanel
                Color.clear.frame(height: 18)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(WhisperWarmBackground())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task(id: pendingQuickActionID) {
            guard let pendingQuickActionID,
                  let action = quickActions.first(where: { $0.id == pendingQuickActionID })
            else { return }
            await controller.sendText(action.message)
            self.pendingQuickActionID = nil
        }
        .accessibilityIdentifier("whisper.chat.home")
    }

    private var homePanel: some View {
        VStack(spacing: 0) {
            brandHeader
                .padding(.top, 22)
                .padding(.bottom, 15)

            coupleSection
                .padding(.bottom, 17)

            WhisperHomeDivider()

            quickActionSection
                .padding(.vertical, 14)

            WhisperHomeDivider()

            latestMessagesSection
                .padding(.vertical, 13)

            enterChatButton
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 15)
        .background(WhisperVisualTheme.panel, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.90), lineWidth: 1)
        )
        .shadow(color: WhisperVisualTheme.pink.opacity(0.10), radius: 24, y: 11)
    }

    private var brandHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                Text("漫长悄悄话")
                    .font(.system(size: 33, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.76)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(WhisperVisualTheme.titleGradient)

            Text("慢慢说，悄悄听")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(WhisperVisualTheme.pink.opacity(0.72))

            if connection != .connected {
                HStack(spacing: 6) {
                    if connection == .connecting { ProgressView().controlSize(.small) }
                    Text(connectionTitle)
                        .font(.caption.weight(.semibold))
                    if connectionIsFailed || connection == .idle {
                        Button("重连", action: onReconnect)
                            .font(.caption.weight(.bold))
                            .buttonStyle(.borderless)
                    }
                }
                .foregroundStyle(connectionIsFailed ? .red : WhisperVisualTheme.pink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.78), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var coupleSection: some View {
        HStack(alignment: .center, spacing: 0) {
            WhisperHomePerson(
                account: currentAccount,
                fallback: currentAccount.username == "xu" ? "🐶" : "🐱",
                status: "嘿嘿",
                ring: WhisperVisualTheme.softPink
            )
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    WhisperDashedRule()
                    Text("💗")
                        .font(.system(size: 23))
                    WhisperDashedRule()
                }
                Text(connection == .connected ? "实时在线" : "正在连接")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
            }
            .frame(width: 82)

            WhisperHomePerson(
                account: partnerAccount,
                fallback: partnerAccount.username == "xu" ? "🐶" : "🐱",
                status: "在想你",
                ring: Color(red: 0.74, green: 0.65, blue: 0.90)
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var quickActionSection: some View {
        HStack(spacing: 9) {
            ForEach(quickActions) { action in
                Button {
                    pendingQuickActionID = action.id
                } label: {
                    VStack(spacing: 7) {
                        Text(pendingQuickActionID == action.id ? "✓" : action.emoji)
                            .font(.system(size: 29))
                        Text(action.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(WhisperVisualTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(action.color.opacity(0.82), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .stroke(WhisperVisualTheme.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(controller.state.isSending)
                .accessibilityLabel(action.title)
            }
        }
    }

    private var latestMessagesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("最新消息", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(WhisperVisualTheme.ink)
                Spacer()
                if controller.state.visibleEntries.isEmpty == false {
                    Text("刚刚")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WhisperVisualTheme.mutedInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.72), in: Capsule())
                }
            }

            let entries = Array(controller.state.messagesByChannel[.couple, default: []].suffix(3))
            if entries.isEmpty {
                Text("还没有消息，进去说第一句吧")
                    .font(.subheadline)
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 7) {
                    ForEach(entries) { entry in
                        WhisperHomeLatestRow(
                            entry: entry,
                            isOutgoing: entry.message.sender == currentAccount.username,
                            avatar: entry.message.sender == currentAccount.username
                                ? currentAccount : partnerAccount
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color(red: 1.00, green: 0.88, blue: 0.94), Color(red: 1.00, green: 0.94, blue: 0.80)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 23, style: .continuous)
        )
    }

    private var enterChatButton: some View {
        Button(action: onOpenChat) {
            HStack(spacing: 9) {
                Text("进入聊天")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WhisperVisualTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .shadow(color: WhisperVisualTheme.pink.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("whisper.chat.home.open-chat")
    }

    private var connectionTitle: String {
        switch connection {
        case .connected: return "已连接"
        case .connecting: return "连接中"
        case .idle: return "已断开"
        case .failed: return "连接失败"
        }
    }

    private var connectionIsFailed: Bool {
        if case .failed = connection { return true }
        return false
    }
}

private struct WhisperHomePerson: View {
    let account: WhisperAccount
    let fallback: String
    let status: String
    let ring: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(status)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(WhisperVisualTheme.pink)
            WhisperAvatarView(
                urlString: account.avatar,
                fallback: fallback,
                size: 103,
                ring: ring
            )
            Text(account.name)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(WhisperVisualTheme.ink)
        }
    }
}

private struct WhisperHomeLatestRow: View {
    let entry: WhisperChatEntry
    let isOutgoing: Bool
    let avatar: WhisperAccount

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if isOutgoing { Spacer(minLength: 48) }

            if isOutgoing == false {
                WhisperAvatarView(
                    urlString: avatar.avatar,
                    fallback: avatar.username == "xu" ? "🐶" : "🐱",
                    size: 34
                )
            }

            Text(entry.message.text ?? "媒体消息")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WhisperVisualTheme.ink)
                .lineLimit(2)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    isOutgoing
                        ? WhisperVisualTheme.softPink.opacity(0.60)
                        : Color.white.opacity(0.76),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )

            if isOutgoing {
                WhisperAvatarView(
                    urlString: avatar.avatar,
                    fallback: avatar.username == "xu" ? "🐶" : "🐱",
                    size: 34
                )
            } else {
                Spacer(minLength: 48)
            }
        }
    }
}

private struct WhisperHomeDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, WhisperVisualTheme.hairline, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

private struct WhisperDashedRule: View {
    var body: some View {
        Rectangle()
            .stroke(WhisperVisualTheme.pink.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .frame(width: 23, height: 1.5)
    }
}
#endif
