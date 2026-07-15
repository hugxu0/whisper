#if canImport(SwiftUI)
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WhisperClients
import WhisperDomain
import WhisperFeatures

private struct WhisperPendingTextSend: Equatable {
    let id = UUID()
    let text: String
    let reply: WhisperMessage?
}

private struct WhisperPendingMediaSend: Equatable {
    let id = UUID()
    let upload: WhisperMediaUpload
    let type: WhisperMessageType
}

@MainActor
public struct WhisperChatView: View {
    @Environment(\.dismiss) private var dismiss

    private let currentAccount: WhisperAccount
    private let partnerAccount: WhisperAccount
    private let connection: WhisperConnectionState
    private let onReconnect: () -> Void

    @State private var controller: WhisperChatController
    @State private var draft = ""
    @State private var replyMessage: WhisperMessage?
    @State private var accessoryMode: WhisperChatAccessoryMode?
    @State private var pendingTextSend: WhisperPendingTextSend?
    @State private var pendingMediaSend: WhisperPendingMediaSend?
    @State private var pendingRetryID: String?
    @State private var pendingRecallID: String?
    @State private var selectedSearchMessage: WhisperMessage?
    @State private var mediaSelection: PhotosPickerItem?
    @State private var stickerSelection: PhotosPickerItem?
    @State private var mediaSelectionRevision = 0
    @State private var stickerSelectionRevision = 0
    @State private var voiceActionRevision = 0
    @State private var syncRevision = 0
    @State private var layoutRevision = 0
    @State private var scrollTargetID: String?
    @State private var showsMoreActions = false
    @State private var showsSearch = false
    @State private var showsFileImporter = false
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    #if os(iOS)
    @State private var voiceRecorder = WhisperVoiceRecorder()
    #endif

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
                hasEarlierMessages: controller.state.hasEarlierMessages,
                isLoadingEarlier: controller.state.isLoadingEarlier,
                currentUsername: controller.state.currentUsername,
                currentAccount: currentAccount,
                partnerAccount: partnerAccount,
                partnerReadTimestamp: controller.state.readTimestamp(for: partnerAccount.username),
                composerFocused: composerFocused,
                layoutRevision: layoutRevision,
                scrollTargetID: scrollTargetID,
                onLoadEarlier: { await controller.loadEarlier() },
                onDismissKeyboard: dismissKeyboard,
                onRetry: retry,
                onReply: beginReply,
                onRecall: recall
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
        .whisperChatPlatformChrome()
        .confirmationDialog("聊天操作", isPresented: $showsMoreActions) {
            Button("搜索聊天记录") { showsSearch = true }
            Button("立即同步") { syncRevision &+= 1 }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showsSearch) {
            WhisperChatSearchView(controller: controller) { message in
                selectedSearchMessage = message
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: handleImportedFile
        )
        .alert("聊天操作失败", isPresented: errorIsPresented) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
        .task {
            if controller.state.channel != .couple { controller.selectChannel(.couple) }
            await controller.markLatestRead()
        }
        .task(id: controller.state.visibleEntries.last?.id) {
            await controller.markLatestRead()
        }
        .task(id: pendingTextSend?.id) { await performPendingTextSend() }
        .task(id: pendingMediaSend?.id) { await performPendingMediaSend() }
        .task(id: pendingRetryID) { await performRetry() }
        .task(id: pendingRecallID) { await performRecall() }
        .task(id: selectedSearchMessage?.id) { await revealSelectedSearchMessage() }
        .task(id: mediaSelectionRevision) { await loadSelectedMedia() }
        .task(id: stickerSelectionRevision) { await loadSelectedSticker() }
        .task(id: voiceActionRevision) { await toggleVoiceRecording() }
        .task(id: syncRevision) {
            guard syncRevision > 0 else { return }
            await controller.synchronize()
        }
        .onChange(of: mediaSelection) { _, item in
            if item != nil { mediaSelectionRevision &+= 1 }
        }
        .onChange(of: stickerSelection) { _, item in
            if item != nil { stickerSelectionRevision &+= 1 }
        }
        .onChange(of: controller.state.lastError) { _, message in
            if let message, message.isEmpty == false { errorMessage = message }
        }
        .onDisappear {
            #if os(iOS)
            voiceRecorder.cancel()
            #endif
        }
        .accessibilityIdentifier("whisper.chat.detail")
    }

    private var topBar: some View {
        WhisperChatTopBar(
            title: partnerAccount.name,
            status: connectionTitle,
            statusColor: connectionColor,
            onBack: goBack,
            onMore: { showsMoreActions = true }
        )
    }

    private var bottomChrome: some View {
        VStack(spacing: 7) {
            if connectionNeedsReconnect { reconnectBanner }

            if let accessoryMode {
                WhisperChatAccessoryPanel(
                    mode: accessoryMode,
                    onEmoji: insertEmoji,
                    onInteraction: sendInteraction,
                    onFile: { showsFileImporter = true },
                    mediaSelection: $mediaSelection,
                    stickerSelection: $stickerSelection
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            WhisperChatComposer(
                draft: $draft,
                focused: $composerFocused,
                reply: replyMessage,
                isRecording: isRecording,
                canSend: canSend,
                onSend: sendDraft,
                onCancelReply: cancelReply,
                onPet: { toggleAccessory(.interactions) },
                onAttachment: { toggleAccessory(.attachments) },
                onEmoji: { toggleAccessory(.emoji) },
                onVoice: voiceButtonPressed
            )
        }
        .animation(.easeInOut(duration: 0.24), value: accessoryMode)
    }

    private var reconnectBanner: some View {
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

    private var canSend: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && connection == .connected
    }

    private var isRecording: Bool {
        #if os(iOS)
        voiceRecorder.isRecording
        #else
        false
        #endif
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

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if $0 == false { errorMessage = nil } }
        )
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, connection == .connected else { return }
        draft = ""
        pendingTextSend = WhisperPendingTextSend(text: text, reply: replyMessage)
        replyMessage = nil
        layoutRevision &+= 1
    }

    private func sendInteraction(_ text: String) {
        pendingTextSend = WhisperPendingTextSend(text: text, reply: nil)
        closeAccessoryPanel()
    }

    private func insertEmoji(_ emoji: String) {
        draft.append(emoji)
        composerFocused = true
        accessoryMode = nil
        layoutRevision &+= 1
    }

    private func beginReply(_ message: WhisperMessage) {
        replyMessage = message
        accessoryMode = nil
        composerFocused = true
        layoutRevision &+= 1
    }

    private func cancelReply() {
        replyMessage = nil
        layoutRevision &+= 1
    }

    private func retry(_ entryID: String) {
        pendingRetryID = entryID
    }

    private func recall(_ entryID: String) {
        pendingRecallID = entryID
    }

    private func toggleAccessory(_ mode: WhisperChatAccessoryMode) {
        dismissKeyboard()
        accessoryMode = accessoryMode == mode ? nil : mode
        layoutRevision &+= 1
    }

    private func closeAccessoryPanel() {
        accessoryMode = nil
        layoutRevision &+= 1
    }

    private func dismissKeyboard() {
        composerFocused = false
    }

    private func goBack() {
        dismissKeyboard()
        closeAccessoryPanel()
        dismiss()
    }

    private func voiceButtonPressed() {
        if connection == .connected {
            voiceActionRevision &+= 1
        } else {
            onReconnect()
        }
    }

    private func performPendingTextSend() async {
        guard let pendingTextSend else { return }
        await controller.sendText(pendingTextSend.text, replyingTo: pendingTextSend.reply)
        self.pendingTextSend = nil
    }

    private func performPendingMediaSend() async {
        guard let pendingMediaSend else { return }
        await controller.sendMedia(pendingMediaSend.upload, as: pendingMediaSend.type)
        self.pendingMediaSend = nil
    }

    private func performRetry() async {
        guard let pendingRetryID else { return }
        await controller.retry(entryID: pendingRetryID)
        self.pendingRetryID = nil
    }

    private func performRecall() async {
        guard let pendingRecallID else { return }
        await controller.recall(entryID: pendingRecallID)
        self.pendingRecallID = nil
    }

    private func revealSelectedSearchMessage() async {
        guard let message = selectedSearchMessage else { return }
        await controller.loadAround(message)
        scrollTargetID = message.id
        self.selectedSearchMessage = nil
    }

    private func loadSelectedMedia() async {
        guard mediaSelectionRevision > 0, let item = mediaSelection else { return }
        defer { mediaSelection = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw WhisperMediaSelectionError.unreadable
            }
            let contentType = item.supportedContentTypes.first ?? .data
            let type: WhisperMessageType = contentType.conforms(to: .movie) ? .video : .image
            let filename = "media-\(UUID().uuidString.lowercased()).\(contentType.preferredFilenameExtension ?? (type == .video ? "mov" : "jpg"))"
            let upload = WhisperMediaUpload(
                data: data,
                filename: filename,
                mimeType: contentType.preferredMIMEType ?? (type == .video ? "video/quicktime" : "image/jpeg")
            )
            await controller.sendMedia(upload, as: type)
            closeAccessoryPanel()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func loadSelectedSticker() async {
        guard stickerSelectionRevision > 0, let item = stickerSelection else { return }
        defer { stickerSelection = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw WhisperMediaSelectionError.unreadable
            }
            let contentType = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .jpeg
            let upload = WhisperMediaUpload(
                data: data,
                filename: "sticker-\(UUID().uuidString.lowercased()).\(contentType.preferredFilenameExtension ?? "jpg")",
                mimeType: contentType.preferredMIMEType ?? "image/jpeg",
                purpose: .sticker
            )
            await controller.sendMedia(upload, as: .sticker)
            closeAccessoryPanel()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let contentType = UTType(filenameExtension: url.pathExtension) ?? .data
            let messageType: WhisperMessageType
            if contentType.conforms(to: .image) {
                messageType = .image
            } else if contentType.conforms(to: .movie) {
                messageType = .video
            } else if contentType.conforms(to: .audio) {
                messageType = .voice
            } else {
                messageType = .file
            }
            pendingMediaSend = WhisperPendingMediaSend(
                upload: WhisperMediaUpload(
                    data: data,
                    filename: url.lastPathComponent,
                    mimeType: contentType.preferredMIMEType ?? "application/octet-stream"
                ),
                type: messageType
            )
            closeAccessoryPanel()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func toggleVoiceRecording() async {
        guard voiceActionRevision > 0 else { return }
        #if os(iOS)
        do {
            if let recording = try await voiceRecorder.toggle() {
                let upload = WhisperMediaUpload(
                    data: recording.data,
                    filename: recording.filename,
                    mimeType: recording.mimeType
                )
                await controller.sendMedia(upload, as: .voice)
            }
            layoutRevision &+= 1
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "当前平台不支持录音"
        #endif
    }
}

private enum WhisperMediaSelectionError: LocalizedError {
    case unreadable

    var errorDescription: String? { "无法读取所选媒体" }
}

private extension View {
    @ViewBuilder
    func whisperChatPlatformChrome() -> some View {
        #if os(iOS)
        self
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden(true)
            .background(
                WhisperInteractivePopRestorer()
                    .frame(width: 0, height: 0)
            )
        #else
        self
        #endif
    }
}
#endif
