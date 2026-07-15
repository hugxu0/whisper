#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

@MainActor
public struct WhisperChatView: View {
    @State private var controller: WhisperChatController
    @State private var draft = ""
    @State private var pendingSend: String?
    @State private var pendingRetryID: String?

    private let connection: WhisperConnectionState
    private let onReconnect: () -> Void

    public init(
        controller: WhisperChatController,
        connection: WhisperConnectionState,
        onReconnect: @escaping () -> Void
    ) {
        _controller = State(initialValue: controller)
        self.connection = connection
        self.onReconnect = onReconnect
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            connectionBanner
            timeline
            composer
        }
        .foregroundStyle(.white)
        .background(background)
        .task(id: pendingSend) {
            guard let pendingSend else { return }
            await controller.sendText(pendingSend)
            self.pendingSend = nil
        }
        .task(id: pendingRetryID) {
            guard let pendingRetryID else { return }
            await controller.retry(entryID: pendingRetryID)
            self.pendingRetryID = nil
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.16),
                Color(red: 0.16, green: 0.10, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Whisper")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(controller.state.currentAccountName ?? "聊天")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                Circle()
                    .fill(connectionColor)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(connectionLabel)
            }

            Picker("聊天频道", selection: Binding(
                get: { controller.state.channel },
                set: { controller.selectChannel($0) }
            )) {
                Text("两个人").tag(WhisperChannel.couple)
                Text("Daju").tag(WhisperChannel.ai)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("whisper.chat.channel-picker")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch connection {
        case .connected:
            EmptyView()
        case .connecting:
            statusBanner("正在连接实时消息…", color: .orange, showsRetry: false)
        case .idle:
            statusBanner("实时消息已断开", color: .orange, showsRetry: true)
        case .failed:
            statusBanner("实时消息连接失败", color: .red, showsRetry: true)
        }
    }

    private func statusBanner(
        _ title: String,
        color: Color,
        showsRetry: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: showsRetry ? "wifi.exclamationmark" : "arrow.triangle.2.circlepath")
                .foregroundStyle(color)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
            if showsRetry {
                Button("重新连接", action: onReconnect)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if controller.state.visibleEntries.isEmpty {
                    emptyState
                }

                ForEach(controller.state.visibleEntries) { entry in
                    WhisperMessageBubble(
                        entry: entry,
                        isOutgoing: entry.message.sender == controller.state.currentUsername,
                        onRetry: { pendingRetryID = entry.id }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("whisper.chat.timeline")
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.55))
            Text("还没有消息")
                .font(.headline)
            Text("从一句简单的问候开始吧")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("写点什么…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("whisper.chat.composer")

            Button {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.isEmpty == false else { return }
                draft = ""
                pendingSend = text
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendDisabled ? .white.opacity(0.28) : .white)
            }
            .disabled(sendDisabled)
            .accessibilityLabel("发送消息")
            .accessibilityIdentifier("whisper.chat.send")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.black.opacity(0.12))
    }

    private var sendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || controller.state.isSending
            || connection != .connected
    }

    private var connectionLabel: String {
        switch connection {
        case .connected: return "已连接"
        case .connecting: return "连接中"
        case .idle: return "已断开"
        case .failed: return "连接失败"
        }
    }

    private var connectionColor: Color {
        switch connection {
        case .connected: return .green
        case .connecting: return .orange
        case .idle, .failed: return .red
        }
    }
}

private struct WhisperMessageBubble: View {
    let entry: WhisperChatEntry
    let isOutgoing: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing { Spacer(minLength: 44) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 5) {
                if isOutgoing == false {
                    Text(entry.message.senderName ?? entry.message.sender)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Text(entry.message.text ?? "")
                    .font(.body)
                    .foregroundStyle(isOutgoing ? .black.opacity(0.82) : .white)
                    .multilineTextAlignment(isOutgoing ? .trailing : .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isOutgoing
                            ? Color.white.opacity(0.92)
                            : Color.white.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 18)
                    )

                deliveryView
            }

            if isOutgoing == false { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
        .accessibilityIdentifier("whisper.chat.message.\(entry.id)")
    }

    @ViewBuilder
    private var deliveryView: some View {
        switch entry.delivery {
        case .sent:
            EmptyView()
        case .sending:
            Text("发送中…")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.52))
        case .failed(let message):
            HStack(spacing: 7) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.90))
                    .lineLimit(1)
                Button("重试", action: onRetry)
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white)
            }
        }
    }
}
#endif
