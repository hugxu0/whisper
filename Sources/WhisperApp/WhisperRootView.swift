#if canImport(SwiftUI)
import SwiftUI
import WhisperDomain
import WhisperFeatures

@MainActor
public struct WhisperRootView: View {
    @State private var session: WhisperSessionController
    @State private var chat: WhisperChatController
    @State private var username = "xu"
    @State private var password = ""
    @State private var pendingRequest: WhisperLoginRequest?
    @State private var attemptID = 0
    @State private var reconnectID = 0

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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.16),
                    Color(red: 0.16, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if session.state.bootstrap != nil {
                    chatContent
                } else {
                    loginContent
                }
            }
            .padding(24)
        }
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
            await chat.monitorEvents()
        }
        .task {
            await session.monitorConnection()
        }
    }

    private var loginContent: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Whisper")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                Text("重新连接属于你们两个人的空间")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Picker("账号", selection: $username) {
                    Text("小旭").tag("xu")
                    Text("小偲").tag("si")
                }
                .pickerStyle(.segmented)

                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let error = session.state.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack(spacing: 10) {
                        if session.state.isLoading {
                            ProgressView()
                        }
                        Text(session.state.isLoading ? "连接中" : "进入 Whisper")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(password.isEmpty || session.state.isLoading)

                if session.state.lastError != nil, pendingRequest != nil {
                    Button("重试") {
                        attemptID &+= 1
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(22)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 440)
    }

    @ViewBuilder
    private var chatContent: some View {
        if session.state.account != nil {
            WhisperChatView(
                controller: chat,
                connection: session.state.connection,
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
