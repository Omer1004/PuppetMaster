import AVFoundation
import OSLog

/// One place that owns the app's audio session category.
///
/// Two subsystems want the session: the sound bank (output) and the microphone
/// (input). Before this existed, releasing the Talk button deactivated the session out
/// from under any sound that was still playing. Recording is now a temporary *upgrade*
/// from playback, and releasing returns to playback rather than going silent.
///
/// Changing the category is not free: it reconfigures the audio hardware underneath
/// every running `AVAudioEngine` in the process. Both engines handle that (see
/// `docs/MIC-CRASH.md`), but it is the reason the upgrade is held for as short a time
/// as possible and never left behind on a failure path.
@MainActor
enum AudioSession {

    private static let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "session")

    /// Whether the session is currently upgraded for input. Tracked here rather than
    /// read back from `AVAudioSession`, because the category can be changed by the
    /// system and the question callers actually have is "did *we* upgrade it".
    private(set) static var isConfiguredForRecording = false

    /// Output only. The default state, and deliberately not `.playAndRecord`: that
    /// category makes the system treat the app as a recording app even when it is not.
    static func activateForPlayback() {
        apply(category: .playback, options: [.mixWithOthers])
        isConfiguredForRecording = false
    }

    /// Output and input, for as long as the Talk button is held.
    ///
    /// Bluetooth input is deliberately **not** requested. Routing input over HFP drags
    /// the whole session down to telephony quality — including the puppet's own sound
    /// effects — and every connect and disconnect reconfigures the hardware. All this
    /// needs is how loud the room is, which the built-in microphone answers perfectly
    /// well even while the user is wearing headphones.
    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
        isConfiguredForRecording = true
    }

    /// Put the session back if — and only if — we are the ones who upgraded it.
    /// Called on every microphone teardown path, including the failures.
    static func returnToPlaybackIfNeeded() {
        guard isConfiguredForRecording else { return }
        activateForPlayback()
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
