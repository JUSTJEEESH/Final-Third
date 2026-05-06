import AVFoundation
import Foundation

/// Owns the app's `AVAudioSession` and an `AVAudioEngine` for ambient mix
/// playback. Voice (LiveKit) is a separate engine; we cooperate via
/// `mixWithOthers` and ducking events.
@MainActor
@Observable
final class AudioEngine {
    private(set) var currentTheme: AudioTheme?
    private(set) var isPlaying: Bool = false
    private(set) var volume: Float = 0.7

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?

    init() {
        configureSession()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func setTheme(_ theme: AudioTheme?) {
        guard theme != currentTheme else { return }
        currentTheme = theme
        if let theme {
            Task { await load(theme: theme) }
        } else {
            stop()
        }
    }

    func setVolume(_ value: Float) {
        volume = max(0, min(1, value))
        player.volume = volume
    }

    /// Ducks ambient mix while voice is active.
    func duck(_ ducked: Bool, animated: Bool = true) {
        let target: Float = ducked ? 0.18 : volume
        if animated {
            // Simple ramp; AVAudioPlayerNode lacks volume ramps so we step.
            let steps = 10
            let from = player.volume
            let dt = 0.025
            Task { @MainActor in
                for i in 1 ... steps {
                    let t = Float(i) / Float(steps)
                    player.volume = from + (target - from) * t
                    try? await Task.sleep(for: .seconds(dt))
                }
            }
        } else {
            player.volume = target
        }
    }

    func stop() {
        player.stop()
        engine.stop()
        isPlaying = false
    }

    // MARK: Internal

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay, .allowBluetoothHFP, .duckOthers]
            )
            try session.setActive(true)
        } catch {
            // Audio is non-critical; never crash on misconfigured devices.
        }
    }

    private func load(theme: AudioTheme) async {
        guard let url = Bundle.main.url(forResource: theme.rawValue, withExtension: "m4a",
                                        subdirectory: "Sounds") else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)) else { return }
            try file.read(into: buffer)
            self.buffer = buffer

            if !engine.isRunning { try engine.start() }
            await player.scheduleBuffer(buffer, at: nil, options: [.loops])
            player.volume = volume
            player.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }
}
