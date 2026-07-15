#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures
#if os(iOS)
import Combine
import UIKit
#endif

struct WhisperChatTimelineView: View {
    let entries: [WhisperChatEntry]
    let hasEarlierMessages: Bool
    let isLoadingEarlier: Bool
    let currentUsername: String?
    let currentAccount: WhisperAccount
    let partnerAccount: WhisperAccount
    let partnerReadTimestamp: Int64
    let composerFocused: Bool
    let layoutRevision: Int
    let scrollTargetID: String?
    let onLoadEarlier: () async -> Void
    let onDismissKeyboard: () -> Void
    let onRetry: (String) -> Void
    let onReply: (WhisperMessage) -> Void
    let onRecall: (String) -> Void

    @State private var bottomIsVisible = true
    @State private var preservedAnchorID: String?

    private let bottomAnchorID = "whisper.chat.timeline.bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: WhisperChatMetrics.messageSpacing) {
                    historyLoader

                    if entries.isEmpty { emptyState }

                    ForEach(entries) { entry in
                        let outgoing = entry.message.sender == currentUsername
                        WhisperMessageBubbleRow(
                            entry: entry,
                            isOutgoing: outgoing,
                            isRead: outgoing && partnerReadTimestamp >= entry.message.ts,
                            account: outgoing ? currentAccount : partnerAccount,
                            onRetry: { onRetry(entry.id) },
                            onReply: { onReply(entry.message) },
                            onRecall: { onRecall(entry.id) }
                        )
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                        .onAppear { bottomIsVisible = true }
                        .onDisappear { bottomIsVisible = false }
                }
                .padding(.horizontal, WhisperChatMetrics.horizontalInset)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .defaultScrollAnchor(.bottom)
            .whisperInteractiveKeyboardDismissal()
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                TapGesture().onEnded { onDismissKeyboard() }
            )
            .onAppear { scrollToBottom(proxy, animated: false) }
            .onChange(of: entries.last?.id) { oldID, _ in
                let lastIsOutgoing = entries.last?.message.sender == currentUsername
                if bottomIsVisible || lastIsOutgoing || oldID == nil {
                    scheduleBottomScroll(proxy, animated: true)
                }
            }
            .onChange(of: entries.first?.id) { _, _ in
                guard let preservedAnchorID else { return }
                Task { @MainActor in
                    await Task.yield()
                    proxy.scrollTo(preservedAnchorID, anchor: .top)
                    self.preservedAnchorID = nil
                }
            }
            .onChange(of: composerFocused) { _, focused in
                if focused { scheduleBottomScroll(proxy, animated: true) }
            }
            .onChange(of: layoutRevision) { _, _ in
                if bottomIsVisible || composerFocused {
                    scheduleBottomScroll(proxy, animated: true)
                }
            }
            .onChange(of: scrollTargetID) { _, target in
                guard let target else { return }
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
            .modifier(
                WhisperKeyboardScrollModifier {
                    if bottomIsVisible || composerFocused {
                        scheduleBottomScroll(proxy, animated: true)
                    }
                }
            )
        }
        .accessibilityIdentifier("whisper.chat.timeline")
    }

    @ViewBuilder
    private var historyLoader: some View {
        if hasEarlierMessages {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("加载更早消息")
                    .font(.caption)
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
            }
            .frame(height: 38)
            .task(id: entries.first?.id) {
                guard isLoadingEarlier == false else { return }
                preservedAnchorID = entries.first?.id
                await onLoadEarlier()
            }
        }
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

    private func scheduleBottomScroll(_ proxy: ScrollViewProxy, animated: Bool) {
        Task { @MainActor in
            await Task.yield()
            await Task.yield()
            scrollToBottom(proxy, animated: animated)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.28)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct WhisperKeyboardScrollModifier: ViewModifier {
    let onKeyboardFrameChange: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )
        ) { _ in
            onKeyboardFrameChange()
        }
        #else
        content
        #endif
    }
}
#endif
