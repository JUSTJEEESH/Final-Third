import AVKit
import SwiftUI

/// Plays a looping muted video clip of a real flame, tinted to match the
/// chosen lighting method. Drop one or more of these video files into the
/// app bundle to replace the procedural Canvas flame:
///
///   - `flame_match.mp4`        (warm yellow-orange)
///   - `flame_torch.mp4`        (blue-white jet)
///   - `flame_cedar.mp4`        (wide amber)
///   - `flame_soft_flame.mp4`   (classic teardrop)
///   - `flame_default.mp4`      (used when a method-specific file is missing)
///
/// Recommended sourcing (CC0 / public domain):
///   - https://www.pexels.com/search/videos/flame/
///   - https://pixabay.com/videos/search/fire/
///   - https://www.videvo.net/  (filter by free / public domain)
///
/// **Important:** the source video should be filmed against a *pure black*
/// background so the `.plusLighter` blend mode treats black as
/// transparent. If the source has a non-black background, edit it down or
/// pick a different clip.
struct RealFlameLayer: View {
    let method: Session.LightingMethod
    var intensity: Double = 1.0

    /// Returns the URL of the matching bundled video, falling back to a
    /// generic flame, then to nil if nothing is bundled.
    private var videoURL: URL? {
        let order = [
            "flame_\(method.rawValue)",
            "flame_default",
        ]
        for name in order {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                return url
            }
        }
        return nil
    }

    var body: some View {
        if let videoURL {
            LoopingPlayerView(url: videoURL)
                .blendMode(.plusLighter)
                .opacity(intensity)
                .accessibilityHidden(true)
        } else {
            // Fall back to the procedural Canvas flame — already used by the
            // ceremony view; this branch only matters if RealFlameLayer is
            // used standalone.
            FlameCanvas(style: .forMethod(method), intensity: intensity)
        }
    }
}

/// AVPlayer-backed view that loops a muted local video. Wrapped in a
/// UIViewRepresentable so we control the AVPlayerLayer aspect fill +
/// looping precisely.
private struct LoopingPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        PlayerContainerView(url: url)
    }

    func updateUIView(_: PlayerContainerView, context _: Context) {}
}

private final class PlayerContainerView: UIView {
    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper
    private let layerHost = AVPlayerLayer()

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        self.player = player
        self.looper = AVPlayerLooper(player: player, templateItem: item)
        super.init(frame: .zero)
        backgroundColor = .black
        player.isMuted = true
        player.actionAtItemEnd = .none
        layerHost.player = player
        layerHost.videoGravity = .resizeAspectFill
        layer.addSublayer(layerHost)
        player.play()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layerHost.frame = bounds
    }
}
