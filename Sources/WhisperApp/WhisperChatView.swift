#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

@MainActor
public struct WhisperChatView: View {
    @Environment(\.dismiss) private var dismiss

    private let currentAccount: WhisperAccount
    private let partnerAccount: WhisperAccount
    private let connection: WhisperConnectionState
    private let onReconnect: () -> Void

    @State private var controller: WhisperChatController
    @State private var draft = ""
    @State private var pendingSend: String?
    @State private var pendingRetryID: String?
    @State private var showsUnavailableAlert = false
    @FocusState private var composerFocused: Bool

    public init(
        controller: WhisperChatController,
        currentAccount: WhisperAccount,
        partnerAccount: WhisperAccount,
        connection: WhisperConnectionState,
        onReconnect: @escaping () -> Void
    ) {
        _controller = State(initialValue: controller)
        self.currentAccount = currentAccount
        self.partnerAccount = partnerAccount
        self.connection = connection
        self.onReconnect = onReconnect
    }

    public var body: some View {
        ZStack {
            WhisperChatBackground()

            WhisperChatTimelineView(
                entries: controller.state.visibleEntries,
                currentUsername: controller.state.currentUsername,
                currentAccount: currentAccount,
                partnerAccount: partnerAccount,
                composerFocused: composerFocused,
                onRetry: retry
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WhisperChatTopBar(
                title: partnerAccount.name,
                status: connectionTitle,
                statusColor: connectionColor,
                onBack: { dismiss() },
                onMore: showUnavailable
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WhisperChatComposer(
                draft: $draft,
                focused: $composerFocused,
                isSending: controller.state.isSending,
                canSend: sendDisabled == false,
                onSend: sendDraft,
                onAccessory: showUnavailable,
                onReconnect: connectionNeedsReconnect ? onReconnect : nil
            )
        }
        .whisperChatPlatformChrome()
        .alert("功能正在接入", isPresented: $showsUnavailableAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("图片、表情和语音会在后续切片接入；当前先保证文字消息、时间线和键盘联动稳定。")
        }
        .task {
            if controller.state.channel != .couple {
                controller.selectChannel(.couple)
            }
        }
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
        .accessibilityIdentifier("whisper.chat.detail")
    }

    private var sendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || controller.state.isSending
            || connection != .connected
    }

    private var connectionNeedsReconnect: Bool {
        switch connection {
        case .idle, .failed: return true
        case .connecting, .connected: return false
        }
    }

    private var connectionTitle: String {
        switch connection {
        case .connected: return "在线"
        case .connecting: return "正在连接"
        case .idle: return "连接已断开"
        case .failed: return "连接失败"
        }
    }

    private var connectionColor: Color {
        switch connection {
        case .connected: return Color(red: 0.18, green: 0.68, blue: 0.39)
        case .connecting: return .orange
        case .idle, .failed: return .red
        }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, sendDisabled == false else { return }
        draft = ""
        pendingSend = text
    }

    private func retry(_ entryID: String) {
        pendingRetryID = entryID
    }

    private func showUnavailable() {
        showsUnavailableAlert = true
    }
}

private extension View {
    @ViewBuilder
    func whisperChatPlatformChrome() -> some View {
        #if os(iOS)
        self
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden(true)
        #else
        self
        #endif
    }
}
#endif
