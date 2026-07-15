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
    @State private var showChatDetail = false

    private let onReconnect: () -> Void

    public init(
        sessionController: WhisperSessionController,
        chatController: WhisperChatController,
        onReconnect: @escaping () -> Void
    ) {
        _session = State(initialValue: sessionController)
        _chat = State(initialValue: chatController)
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
                        connection: session.state.connection,
                        onReconnect: onReconnect
                    )
                }
            }
            .tag(WhisperMainTab.chat)

            placeholderTab(.moments)
                .tag(WhisperMainTab.moments)
            placeholderTab(.pet)
                .tag(WhisperMainTab.pet)
            placeholderTab(.plans)
                .tag(WhisperMainTab.plans)
            placeholderTab(.account)
                .tag(WhisperMainTab.account)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showChatDetail == false {
                WhisperBottomBar(selection: $selectedTab)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 7)
            }
        }
        .background(WhisperWarmBackground())
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .chat {
                showChatDetail = false
            }
        }
    }

    private var currentAccount: WhisperAccount {
        session.state.account
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

private struct WhisperBottomBar: View {
    @Binding var selection: WhisperMainTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WhisperMainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .semibold))
                            if tab == .plans {
                                Text("1")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 17, height: 17)
                                    .background(WhisperVisualTheme.pink, in: Circle())
                                    .offset(x: 11, y: -8)
                            }
                        }
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(
                        selection == tab ? WhisperVisualTheme.pink : WhisperVisualTheme.ink
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        selection == tab
                            ? WhisperVisualTheme.softPink.opacity(0.68)
                            : .clear,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.84), lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 7)
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
        .navigationBarHidden(true)
    }
}
#endif
