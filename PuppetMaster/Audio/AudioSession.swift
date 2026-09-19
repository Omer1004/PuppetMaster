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
/// make at any time, and the sound bank's recovery handler used one of them — so every
/// Talk press became a fight between the two engines over the category.
///
/// Owners now declare what they need and never name a category themselves. Two rules
/// keep that honest, and both exist because breaking them froze the app on device:
///
/// 1. **Nobody re-applies the session from a configuration-change handler.** Applying a
///    category is what posts that notification. `AudioRecovery` holds this rule.
/// 2. **Applying a category the session already has is skipped.** It is not a no-op in
///    AVFoundation — it reconfigures the hardware and posts the notification anyway.
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
    /// **Only for events that took the session away from us** — an interruption ending,
    /// or media services restarting. Never for an ordinary configuration change:
    /// applying a category is what *posts* that notification, so a handler that responds
    /// to it by applying a category re-triggers itself until the main queue is saturated
    /// and the app is frozen. `AudioRecovery` holds that rule and the reasoning.
    static func reassert() {
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
            try setCategoryIfNeeded(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            return true
        } catch {
            // Losing sound is a degraded experience, never a broken one.
            log.error("Could not configure audio session: \(error.localizedDescription)")
            return false
        }
    }

    private static func applyRecording() throws {
        try setCategoryIfNeeded(.playAndRecord,
                                options: [.defaultToSpeaker, .mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
    }

    /// Setting a category the session already has is **not** free: it still reconfigures
    /// the audio hardware, and that posts `AVAudioEngineConfigurationChange` to every
    /// running engine. Skipping the redundant call is what stops a recovery handler from
    /// feeding itself. Belt and braces with `AudioRecovery` — the callers should not be
    /// asking in the first place, and if one does, it costs nothing.
    private static func setCategoryIfNeeded(_ category: AVAudioSession.Category,
                                            options: AVAudioSession.CategoryOptions) throws {
        let session = AVAudioSession.sharedInstance()
        guard session.category != category || session.categoryOptions != options else {
            return
        }
        noteHardwareReconfiguration()
        try session.setCategory(category, mode: .default, options: options)
    }

    // MARK: Tripwire

    /// Every loop of the kind described above has to pass through here, because this is
    /// the only place the app reconfigures the audio hardware.
    ///
    /// Twice now a recovery handler has fed itself and frozen the app on device, and
    /// both times there was nothing to look at afterwards: a livelock produces no crash
    /// report, no exception and no stack. This turns the next one into a `fault` in
    /// Console naming the file to look at — cheap insurance on a bug class that cannot
    /// happen in the Simulator and is silent on device.
    private static var recentChanges: [Date] = []
    private static let changeWindow: TimeInterval = 2
    /// A Talk press plus a route change is a handful. Past this it is a loop.
    private static let changeLimit = 8

    private static func noteHardwareReconfiguration() {
        let now = Date()
        recentChanges.removeAll { now.timeIntervalSince($0) > changeWindow }
        recentChanges.append(now)
        guard recentChanges.count > changeLimit else { return }
        log.fault("Audio session category changed \(recentChanges.count, privacy: .public) times in \(changeWindow, privacy: .public)s — something is re-applying the session from a configuration-change handler. See AudioRecovery. The app is about to freeze.")
        recentChanges.removeAll()
    }
}
