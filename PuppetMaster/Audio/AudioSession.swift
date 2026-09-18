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
///
/// **This type holds the intent, and the intent is the single source of truth.** The
/// first version was a stateless pair of `activateFor…` calls that either owner could
/// make at any time, and that had a bug with teeth: the sound bank's
/// configuration-change handler called `activateForPlayback()`, but the thing that
/// posts a configuration change is the microphone upgrading the session. So every Talk
/// press became a fight — mic goes to `.playAndRecord`, sound bank drags it back to
/// `.playback` while the user is still holding the button, mic sees *that* change and
/// upgrades again. Owners now declare what they need and ask for the intent to be
/// re-applied; they never name a category themselves.
@MainActor
enum AudioSession {

    private static let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "session")

    enum Intent {
        /// Output only. The default, and deliberately not `.playAndRecord`: that
        /// category makes the system treat the app as a recording app even when it is
        /// not, which shows the recording indicator and dims other audio.
        case playback
        /// Output and input, for as long as the Talk button is held.
        case recording
    }

    /// What the app currently wants the session to be — not necessarily what it is.
    /// If applying a category fails, the intent stays put so the next attempt retries
    /// rather than silently giving up.
    private(set) static var intent: Intent = .playback

    /// Whether *we* asked for input. Deliberately derived from the intent rather than
    /// read back from `AVAudioSession`, because the system can change the category on
    /// its own and the question callers actually have is "did we upgrade it".
    static var isConfiguredForRecording: Bool { intent == .recording }

    static func activateForPlayback() {
        guard applyPlayback() else {
            // The session may still be `.playAndRecord`. Leaving the intent alone means
            // `returnToPlaybackIfNeeded()` will try again instead of believing a
            // downgrade that never happened — the recording-indicator leak that
            // docs/MIC-CRASH.md calls Leak C.
            log.error("Staying in \(String(describing: intent)) — the downgrade failed")
            return
        }
        intent = .playback
    }

    /// Bluetooth input is deliberately **not** requested. Routing input over HFP drags
    /// the whole session down to telephony quality — including the puppet's own sound
    /// effects — and every connect and disconnect reconfigures the hardware. All this
    /// needs is how loud the room is, which the built-in microphone answers perfectly
    /// well even while the user is wearing headphones.
    static func activateForRecording() throws {
        try applyRecording()
        intent = .recording
    }

    /// Put the session back if — and only if — we are the ones who upgraded it.
    /// Called on every microphone teardown path, including the failures.
    static func returnToPlaybackIfNeeded() {
        guard intent == .recording else { return }
        activateForPlayback()
    }

    /// Re-assert whatever is currently intended, without changing it.
    ///
    /// This is what an engine calls after the system has pulled its graph apart. It is
    /// the *only* correct thing to call there: a rebuild triggered by the microphone
    /// starting must not undo the microphone starting.
    static func reactivate() {
        switch intent {
        case .playback:
            _ = applyPlayback()
        case .recording:
            do {
                try applyRecording()
            } catch {
                // Input is gone and cannot be restored. Fall back rather than leaving a
                // half-configured session behind; VoiceInput's own recovery path will
                // notice the microphone did not come back and switch to the silly voice.
                log.error("Could not re-assert recording: \(error.localizedDescription)")
                activateForPlayback()
            }
        }
    }

    private static func applyPlayback() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            return true
        } catch {
            // Losing sound is a degraded experience, never a broken one.
            log.error("Could not configure audio session: \(error.localizedDescription)")
            return false
        }
    }

    private static func applyRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
    }
}
