#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

@MainActor
public struct WhisperRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: WhisperSessionController
    @State private var chat: WhisperChatController
    @State private var username = "xu"
    @State private var password = ""
    @State private var pendingRequest: WhisperLoginRequest?
    @State private var attemptID = 0
    @State private var reconnectID = 0
    @State private var recoveryID = 0

    private let device: WhisperDeviceDescription

    public init(
        sessionController: WhisperSessionController,
        chatController: WhisperChatController,
        device: WhisperDeviceDescription
    ) {
        _session = State(initialValue: sessionController)
        _chat = State(initialValue: chatController)
        self.device = device
    }

    public var body: some View {
        Group {
            if session.state.bootstrap != nil {
                chatContent
            } else {
                loginContent
                    .padding(24)
            }
        }
        .background(WhisperWarmBackground())
        .task(id: attemptID) {
            guard let pendingRequest else { return }
            await session.start(request: pendingRequest)
            if session.state.bootstrap != nil {
                password = ""
                self.pendingRequest = nil
            }
        }
        .task(id: reconnectID) {
            guard reconnectID > 0 else { return }
            await session.reconnect()
            if session.state.connection == .connected {
                await chat.synchronize()
            }
        }
        .task(id: session.state.bootstrap?.serverTime) {
            guard let bootstrap = session.state.bootstrap,
                  let account = session.state.account
            else { return }
            chat.load(
                bootstrap: bootstrap,
                username: account.username,
                accountName: account.name
            )
            async let monitoring: Void = chat.monitorEvents()
            await chat.synchronize()
            await chat.restoreOutboxAndRetry()
            await monitoring
        }
        .task {
            await session.monitorConnection()
        }
        .task(id: recoveryID) {
            guard recoveryID > 0, session.state.bootstrap != nil else { return }
            if session.state.connection == .connected {
                await chat.synchronize()
            } else {
                await session.reconnect()
                if session.state.connection == .connected {
                    await chat.synchronize()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, session.state.bootstrap != nil {
                recoveryID &+= 1
            }
        }
    }

    private var loginContent: some View {
        VStack(spacing: 26) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(WhisperVisualTheme.primaryGradient)
                .padding(.bottom, -8)

            VStack(spacing: 8) {
                Text("悄悄话")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(WhisperVisualTheme.titleGradient)
                Text("只属于我们俩的小空间")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WhisperVisualTheme.mutedInk)
            }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    loginAccountButton(username: "xu", name: "小旭", avatar: "🐶")
                    loginAccountButton(username: "si", name: "小偲", avatar: "🐱")
                }

                SecureField("密码", text: $password)
                    .textContentType(.password)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(WhisperVisualTheme.hairline, lineWidth: 1)
                    )

                if let error = session.state.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color.red.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack(spacing: 10) {
                        if session.state.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(session.state.isLoading ? "连接中" : "进入悄悄话")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(WhisperVisualTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: WhisperVisualTheme.pink.opacity(0.24), radius: 12, y: 6)
                .disabled(password.isEmpty || session.state.isLoading)

                if session.state.lastError != nil, pendingRequest != nil {
                    Button("重试") {
                        attemptID &+= 1
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(22)
            .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: WhisperVisualTheme.pink.opacity(0.12), radius: 22, y: 10)
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loginAccountButton(username value: String, name: String, avatar: String) -> some View {
        Button {
            username = value
        } label: {
            HStack(spacing: 9) {
                WhisperAvatarView(urlString: nil, fallback: avatar, size: 38)
                Text(name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WhisperVisualTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                username == value ? WhisperVisualTheme.softPink.opacity(0.76) : Color.white.opacity(0.62),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(username == value ? WhisperVisualTheme.pink.opacity(0.45) : WhisperVisualTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(name)")
        .accessibilityAddTraits(username == value ? .isSelected : [])
    }

    @ViewBuilder
    private var chatContent: some View {
        if session.state.account != nil {
            WhisperMainTabView(
                sessionController: session,
                chatController: chat,
                onReconnect: { reconnectID &+= 1 }
            )
        }
    }

    private func submit() {
        pendingRequest = WhisperLoginRequest(
            username: username,
            password: password,
            device: device
        )
        attemptID &+= 1
    }
}
#endif
