import AVFoundation
import OSLog

/// One place that owns the app's audio session category.
///
/// Two subsystems want the session: the sound bank (output) and the microphone
/// (input). Before this existed, releasing the Talk button deactivated the session out
/// from under any sound that was still playing. Recording is now a temporary *upgrade*
/// from playback, and releasing returns to playback rather than going silent.
@MainActor
enum AudioSession {

    private static let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "session")

    /// Output only. The default state, and deliberately not `.playAndRecord`: that
    /// category makes the system treat the app as a recording app even when it is not.
    static func activateForPlayback() {
        apply(category: .playback, options: [.mixWithOthers])
    }

    /// Output and input, for as long as the Talk button is held.
    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try session.setActive(true)
    }

    private static func apply(category: AVAudioSession.Category,
                              options: AVAudioSession.CategoryOptions) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(category, mode: .default, options: options)
            try session.setActive(true)
        } catch {
            // Losing sound is a degraded experience, never a broken one.
            log.error("Could not configure audio session: \(error.localizedDescription)")
        }
    }
}
