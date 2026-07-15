#if canImport(SwiftUI)
import SwiftUI

struct WhisperChatBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WhisperVisualTheme.chatBlush,
                    WhisperVisualTheme.chatLavender,
                    WhisperVisualTheme.chatButter
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WhisperVisualTheme.pink.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: 150, y: -290)

            Circle()
                .fill(Color.white.opacity(0.58))
                .frame(width: 230, height: 230)
                .blur(radius: 44)
                .offset(x: -170, y: 180)

            Circle()
                .fill(WhisperVisualTheme.chatButter.opacity(0.72))
                .frame(width: 260, height: 260)
                .blur(radius: 58)
                .offset(x: 140, y: 380)
        }
        .ignoresSafeArea()
    }
}

struct WhisperChatTopBar: View {
    let title: String
    let status: String
    let statusColor: Color
    let onBack: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            WhisperGlassIconButton(
                systemName: "chevron.left",
                size: WhisperChatMetrics.topControlSize,
                accessibilityLabel: "返回",
                action: onBack
            )

            Spacer(minLength: 0)

            titlePill

            Spacer(minLength: 0)

            WhisperGlassIconButton(
                systemName: "ellipsis",
                size: WhisperChatMetrics.topControlSize,
                tint: WhisperVisualTheme.chatRose,
                accessibilityLabel: "更多",
                action: onMore
            )
        }
        .padding(.horizontal, WhisperChatMetrics.horizontalInset)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(WhisperChatChromeFade(edge: .top))
    }

    private var titlePill: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(WhisperVisualTheme.ink)
                .lineLimit(1)

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: WhisperChatMetrics.topControlSize)
        .whisperGlass(in: Capsule(), tint: WhisperVisualTheme.chatRose.opacity(0.05))
        .accessibilityElement(children: .combine)
    }
}

struct WhisperGlassIconButton: View {
    let systemName: String
    var size: CGFloat = WhisperChatMetrics.composerControlHeight
    var tint: Color = WhisperVisualTheme.ink
    var isEnabled = true
    var isActive = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .whisperGlass(
            in: Circle(),
            tint: tint.opacity(isActive ? 0.18 : 0.06),
            interactive: true
        )
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct WhisperChatChromeFade: View {
    enum Edge: Equatable { case top, bottom }

    let edge: Edge

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    WhisperVisualTheme.chatBlush.opacity(0.56),
                    WhisperVisualTheme.chatLavender.opacity(0.22),
                    .clear
                ],
                startPoint: edge == .top ? .top : .bottom,
                endPoint: edge == .top ? .bottom : .top
            )
        }
        .mask(
            LinearGradient(
                colors: [.black, .black.opacity(0.88), .clear],
                startPoint: edge == .top ? .top : .bottom,
                endPoint: edge == .top ? .bottom : .top
            )
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
#endif
