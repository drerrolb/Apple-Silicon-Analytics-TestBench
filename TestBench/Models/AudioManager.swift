import AVFoundation

/// Manages background ambient music playback for the benchmark app.
///
/// Plays `kiraa-10m-music.mp3` on a loop at low volume to create atmosphere.
/// Uses `AVAudioPlayer` which works in-process without requiring background
/// audio entitlements (the app stays in the foreground during benchmarks).
final class AudioManager: @unchecked Sendable {

    static let shared = AudioManager()

    private var player: AVAudioPlayer?

    private init() {}

    /// Start playing the ambient music on loop at quiet volume.
    /// No-ops if the audio file isn't found in the bundle.
    func startAmbientMusic() {
        guard player == nil else { return }  // already playing

        guard let url = Bundle.main.url(forResource: "kiraa-10m-music", withExtension: "mp3") else {
            return
        }

        do {
            // Configure audio session for ambient playback (mixes with other audio)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1   // loop forever
            player?.volume = 0.15        // quiet background level
            player?.play()
        } catch {
            // Silently fail — music is non-critical
        }
    }

    /// Stop the ambient music.
    func stopAmbientMusic() {
        player?.stop()
        player = nil
    }
}
