#if canImport(SwiftUI)
import SwiftUI

enum WhisperVisualTheme {
    static let pageTop = Color(red: 1.00, green: 0.92, blue: 0.94)
    static let pageBottom = Color(red: 1.00, green: 0.97, blue: 0.88)
    static let panel = Color.white.opacity(0.92)
    static let pink = Color(red: 0.95, green: 0.20, blue: 0.48)
    static let softPink = Color(red: 1.00, green: 0.82, blue: 0.88)
    static let blue = Color(red: 0.20, green: 0.44, blue: 0.88)
    static let purple = Color(red: 0.42, green: 0.22, blue: 0.84)
    static let ink = Color(red: 0.15, green: 0.13, blue: 0.16)
    static let mutedInk = Color(red: 0.42, green: 0.37, blue: 0.42)
    static let hairline = Color.black.opacity(0.07)
    static let chatRose = Color(red: 0.96, green: 0.22, blue: 0.47)
    static let chatBlush = Color(red: 1.00, green: 0.91, blue: 0.94)
    static let chatLavender = Color(red: 0.96, green: 0.91, blue: 1.00)
    static let chatButter = Color(red: 1.00, green: 0.97, blue: 0.83)

    static let titleGradient = LinearGradient(
        colors: [blue, purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryGradient = LinearGradient(
        colors: [Color(red: 1.00, green: 0.25, blue: 0.48), pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct WhisperWarmBackground: View {
    var body: some View {
        LinearGradient(
            colors: [WhisperVisualTheme.pageTop, WhisperVisualTheme.pageBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct WhisperAvatarView: View {
    let urlString: String?
    let fallback: String
    let size: CGFloat
    let ring: Color

    init(
        urlString: String?,
        fallback: String,
        size: CGFloat,
        ring: Color = WhisperVisualTheme.softPink
    ) {
        self.urlString = urlString
        self.fallback = fallback
        self.size = size
        self.ring = ring
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.88))
            .clipShape(Circle())
            .overlay(Circle().stroke(ring.opacity(0.72), lineWidth: 3))
            .shadow(color: ring.opacity(0.22), radius: 8, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackView
                }
            }
        } else {
            fallbackView
        }
    }

    private var fallbackView: some View {
        Text(fallback)
            .font(.system(size: size * 0.42))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    @ViewBuilder
    func whisperGlass<GlassShape: Shape>(
        in shape: GlassShape,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            let effect = interactive
                ? Glass.regular.tint(tint).interactive()
                : Glass.regular.tint(tint)
            self.glassEffect(effect, in: shape)
        } else {
            self.whisperMaterialFallback(in: shape)
        }
        #else
        self.whisperMaterialFallback(in: shape)
        #endif
    }

    private func whisperMaterialFallback<GlassShape: Shape>(
        in shape: GlassShape
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.72), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 14, y: 6)
    }

    @ViewBuilder
    func whisperInteractiveKeyboardDismissal() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}
#endif
