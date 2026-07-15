#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

@MainActor
struct WhisperChatSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var controller: WhisperChatController
    @State private var query = ""
    @State private var searchRequestID = 0

    let onSelect: (WhisperMessage) -> Void

    init(controller: WhisperChatController, onSelect: @escaping (WhisperMessage) -> Void) {
        _controller = State(initialValue: controller)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Group {
                if controller.state.isSearching {
                    ProgressView("正在搜索")
                } else if controller.state.searchResults.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "搜索聊天记录" : "没有找到消息",
                        systemImage: "magnifyingglass",
                        description: Text(query.isEmpty ? "输入关键词查找当前会话" : "换一个关键词试试")
                    )
                } else {
                    List(controller.state.searchResults, id: \.id) { message in
                        Button {
                            onSelect(message)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(message.senderName ?? message.sender)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WhisperVisualTheme.chatRose)
                                    Spacer()
                                    Text(messageDate(message), format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(WhisperMessagePresentation(message: message).previewText)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("搜索消息")
            .whisperSearchNavigationStyle()
            .searchable(text: $query, prompt: "关键词")
            .onSubmit(of: .search) { searchRequestID &+= 1 }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("搜索") { searchRequestID &+= 1 }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task(id: searchRequestID) {
                guard searchRequestID > 0 else { return }
                await controller.search(query)
            }
        }
    }

    private func messageDate(_ message: WhisperMessage) -> Date {
        let raw = Double(message.ts)
        return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
    }
}

private extension View {
    @ViewBuilder
    func whisperSearchNavigationStyle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
#endif
