#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

public enum WhisperMainTab: String, CaseIterable, Hashable, Identifiable, Sendable {
    case chat = "聊天"
    case moments = "时光"
    case pet = "大橘"
    case plans = "计划"
    case account = "我的"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: return "ellipsis.message.fill"
        case .moments: return "clock.arrow.circlepath"
        case .pet: return "pawprint.fill"
        case .plans: return "calendar"
        case .account: return "person.fill"
        }
    }
}

@MainActor
public struct WhisperMainTabView: View {
    @State private var session: WhisperSessionController
    @State private var chat: WhisperChatController
    @State private var selectedTab: WhisperMainTab = .chat
    @State private var showChatDetail: Bool

    private let onReconnect: () -> Void

    public init(
        sessionController: WhisperSessionController,
        chatController: WhisperChatController,
        onReconnect: @escaping () -> Void
    ) {
        _session = State(initialValue: sessionController)
        _chat = State(initialValue: chatController)
        _showChatDetail = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("-WhisperOpenChatDetail")
        )
        self.onReconnect = onReconnect
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WhisperChatHomeView(
                    controller: chat,
                    currentAccount: currentAccount,
                    partnerAccount: partnerAccount,
                    connection: session.state.connection,
                    onOpenChat: { showChatDetail = true },
                    onReconnect: onReconnect
                )
                .navigationDestination(isPresented: $showChatDetail) {
                    WhisperChatView(
                        controller: chat,
                        currentAccount: currentAccount,
                        partnerAccount: partnerAccount,
                        connection: session.state.connection,
                        onReconnect: onReconnect
                    )
                }
            }
            .tag(WhisperMainTab.chat)
            .tabItem {
                Label(WhisperMainTab.chat.rawValue, systemImage: WhisperMainTab.chat.icon)
            }

            placeholderTab(.moments)
                .tag(WhisperMainTab.moments)
                .tabItem {
                    Label(WhisperMainTab.moments.rawValue, systemImage: WhisperMainTab.moments.icon)
                }
            placeholderTab(.pet)
                .tag(WhisperMainTab.pet)
                .tabItem {
                    Label(WhisperMainTab.pet.rawValue, systemImage: WhisperMainTab.pet.icon)
                }
            placeholderTab(.plans)
                .tag(WhisperMainTab.plans)
                .tabItem {
                    Label(WhisperMainTab.plans.rawValue, systemImage: WhisperMainTab.plans.icon)
                }
                .badge(1)
            placeholderTab(.account)
                .tag(WhisperMainTab.account)
                .tabItem {
                    Label(WhisperMainTab.account.rawValue, systemImage: WhisperMainTab.account.icon)
                }
        }
        .tint(WhisperVisualTheme.pink)
        .background(WhisperWarmBackground())
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .chat {
                showChatDetail = false
            }
        }
    }

    private var currentAccount: WhisperAccount {
        session.state.bootstrap?.accounts.first(where: {
            $0.username == session.state.account?.username
        })
            ?? session.state.account
            ?? WhisperAccount(username: "xu", name: "小旭", avatar: nil)
    }

    private var partnerAccount: WhisperAccount {
        session.state.bootstrap?.accounts.first(where: {
            $0.username != currentAccount.username
        })
        ?? WhisperAccount(
            username: currentAccount.username == "xu" ? "si" : "xu",
            name: currentAccount.username == "xu" ? "小偲" : "小旭",
            avatar: nil
        )
    }

    private func placeholderTab(_ tab: WhisperMainTab) -> some View {
        NavigationStack {
            WhisperPlaceholderView(tab: tab)
        }
    }
}

private struct WhisperPlaceholderView: View {
    let tab: WhisperMainTab

    var body: some View {
        ZStack {
            WhisperWarmBackground()
            VStack(spacing: 14) {
                Image(systemName: tab.icon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(WhisperVisualTheme.pink)
                Text(tab.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(WhisperVisualTheme.ink)
                Text("这个页面会在后续切片中接入")
                    .font(.subheadline)
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}
#endif
