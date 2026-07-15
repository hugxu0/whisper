#if canImport(SwiftUI)
import AVKit
import SwiftUI
import WhisperDomain

struct WhisperMediaPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let media: WhisperPresentedMedia
    let kind: WhisperMessagePresentationKind

    @State private var player: AVPlayer?

    init(media: WhisperPresentedMedia, kind: WhisperMessagePresentationKind) {
        self.media = media
        self.kind = kind
        let url = Self.resolve(media.url)
        _player = State(initialValue: (kind == .video || kind == .voice) ? url.map(AVPlayer.init(url:)) : nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                previewContent
            }
            .navigationTitle(previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if let url = resolvedURL {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openURL(url)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("在其他应用中打开")
                    }
                }
            }
            .onAppear {
                if kind == .voice { player?.play() }
            }
            .onDisappear { player?.pause() }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch kind {
        case .image, .sticker:
            AsyncImage(url: resolvedURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    ContentUnavailableView("媒体加载失败", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.white)
                default:
                    ProgressView().tint(.white)
                }
            }
            .padding(kind == .sticker ? 28 : 0)
        case .video, .voice:
            if let player {
                VideoPlayer(player: player)
            } else {
                ContentUnavailableView("媒体不可用", systemImage: "play.slash")
                    .foregroundStyle(.white)
            }
        case .file:
            VStack(spacing: 16) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 56))
                Text("使用右上角按钮打开文件")
                    .font(.headline)
            }
            .foregroundStyle(.white)
        default:
            ContentUnavailableView("无法预览", systemImage: "questionmark.square.dashed")
                .foregroundStyle(.white)
        }
    }

    private var resolvedURL: URL? { Self.resolve(media.url) }

    private var previewTitle: String {
        switch kind {
        case .image: return "图片"
        case .sticker: return "表情"
        case .video: return "视频"
        case .voice: return "语音"
        case .file: return "文件"
        default: return "媒体"
        }
    }

    private static func resolve(_ rawValue: String) -> URL? {
        if let url = URL(string: rawValue), url.scheme != nil { return url }
        guard let baseURL = URL(string: "https://hoo66.top") else { return nil }
        return URL(string: rawValue, relativeTo: baseURL)?.absoluteURL
    }
}
#endif
