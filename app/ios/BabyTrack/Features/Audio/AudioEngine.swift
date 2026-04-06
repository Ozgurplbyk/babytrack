import Foundation
import AVFoundation

@MainActor
final class AudioEngine: ObservableObject {
    @Published var currentlyPlaying: String?

    private var player: AVAudioPlayer?

    func play(assetPath: String, fileExtension ext: String = "wav") {
        stop()

        let nsPath = assetPath as NSString
        let fileName = nsPath.lastPathComponent
        let directory = nsPath.deletingLastPathComponent

        guard let url = Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: directory) else {
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            player?.play()

            currentlyPlaying = assetPath
        } catch {
            currentlyPlaying = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentlyPlaying = nil
    }
}
