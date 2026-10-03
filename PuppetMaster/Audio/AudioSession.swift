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
/// 1. **Nobody upgrades or re-applies the session from a configuration-change
///    handler.** Applying a category is what posts that notification. `AudioRecovery`
///    holds the rule, and this type enforces it: inside a handler, anything but a
///    downgrade is refused.
/// 2. **Applying a configuration the session already has is skipped.** It is not a
///    no-op in AVFoundation — it reconfigures the hardware and posts the notification
///    anyway. `SessionConfiguration.needsApplying` decides.
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

    enum SessionError: Error {
        /// Something tried to upgrade or re-apply the session from inside a
        /// configuration-change handler — the freeze. See `AudioRecovery`.
        case insideConfigurationChange
    }

    /// What the app currently wants the session to be.
    ///
    /// Only ever what is *wanted*. The first fix for Leak C left this at `.recording`
    /// after a downgrade failed, so that the next attempt would retry — but `reassert()`
    /// read it as "the microphone wants input" and, after a phone call ended, put the
    /// app back into `.playAndRecord` with nothing recording. "We still owe a downgrade"
    /// is a different fact, and now has its own flag.
    private(set) static var intent: Intent = .playback

    /// A downgrade to playback that did not take. The session may still be
    /// `.playAndRecord`, showing the recording indicator and dimming other audio, so the
    /// next chance — a teardown, an interruption ending — tries again. The leak that
    /// docs/MIC-CRASH.md calls Leak C.
    private static var downgradeOwed = false

    /// The last configuration this app successfully applied. Lets `needsApplying` see
    /// past an option set iOS reported back normalised.
    private static var lastApplied: SessionConfiguration?

    /// Whether *we* asked for input. Deliberately derived from the intent rather than
    /// read back from `AVAudioSession`, because the system can change the category on
    /// its own and the question callers actually have is "did we upgrade it".
    static var isConfiguredForRecording: Bool { intent == .recording }

    /// Apply whatever is intended. For start-up only — no system event brought us here,
    /// so there is nothing to recover from and nothing to force.
    static func establish() {
        switch intent {
        case .playback:
            settleOnPlayback(force: false)
        case .recording:
            // Not reachable today: nothing records before the sound bank starts. If it
            // ever is, keep the input rather than silently dropping it.
            reassertRecording(force: false)
        }
    }

    /// Bluetooth input is deliberately **not** requested. Routing input over HFP drags
    /// the whole session down to telephony quality — including the puppet's own sound
    /// effects — and every connect and disconnect reconfigures the hardware. All this
    /// needs is how loud the room is, which the built-in microphone answers perfectly
    /// well even while the user is wearing headphones.
    static func activateForRecording() throws {
        do {
            try apply(.recording, force: false)
        } catch {
            // `setCategory` can succeed and `setActive` fail, so a throw does not mean
            // the session is untouched. Owe the downgrade, so the caller's unwind
            // actually performs it instead of believing there is nothing to undo.
            downgradeOwed = true
            throw error
        }
        intent = .recording
    }

    /// Put the session back if — and only if — we upgraded it, or tried to and may have
    /// left it half-done. Called on every microphone teardown path, including failures.
    static func returnToPlaybackIfNeeded() {
        guard intent == .recording || downgradeOwed else { return }
        settleOnPlayback(force: false)
    }

    /// Re-assert whatever is currently intended, without changing it.
    ///
    /// **Only for events that took the session away from us** — an interruption ending,
    /// or media services restarting. Taking the event, rather than trusting the caller,
    /// means a configuration change cannot get through here by accident: it is refused
    /// and logged. After a media services reset the configuration is applied in full,
    /// whatever the session claims, because its read-back cannot be believed.
    static func reassert(after event: AudioRecovery.Event) {
        guard AudioRecovery.needsSessionReassertion(after: event) else {
            log.fault("Refused to re-assert the audio session after \(String(describing: event), privacy: .public). This event must not touch the session — see AudioRecovery.")
            return
        }
        let force = !AudioRecovery.sessionStateIsTrustworthy(after: event)
        switch intent {
        case .playback:  settleOnPlayback(force: force)
        case .recording: reassertRecording(force: force)
        }
    }

    // MARK: Applying

    private static func reassertRecording(force: Bool) {
        do {
            try apply(.recording, force: force)
        } catch {
            // Input is gone and cannot be restored. Fall back rather than leaving a
            // half-configured session behind; the microphone checks
            // `isConfiguredForRecording` before rebuilding and will hand over to the
            // silly voice.
            log.error("Could not re-assert recording: \(error.localizedDescription)")
            settleOnPlayback(force: force)
        }
    }

    /// Want playback, apply it, and remember whether it took.
    private static func settleOnPlayback(force: Bool) {
        intent = .playback
        do {
            try apply(.playback, force: force)
            downgradeOwed = false
        } catch {
            // Losing sound is a degraded experience, never a broken one. But the session
            // may still be `.playAndRecord`, so the next chance retries.
            downgradeOwed = true
            log.error("Could not configure audio session for playback: \(error.localizedDescription)")
        }
    }

    private static func apply(_ configuration: SessionConfiguration, force: Bool) throws {
        // The enforcement half of AudioRecovery's rule. A downgrade is let through: it
        // is how a failed rebuild hands the session back, and it cannot loop on its own.
        if AudioRecovery.isHandlingConfigurationChange, configuration != .playback {
            log.fault("Refused to apply \(configuration.category.rawValue, privacy: .public) from inside a configuration-change handler. Doing so re-posts the notification and freezes the app — see AudioRecovery.")
            throw SessionError.insideConfigurationChange
        }

        let session = AVAudioSession.sharedInstance()
        let current = SessionConfiguration(category: session.category,
                                           mode: session.mode,
                                           options: session.categoryOptions)
        if force || SessionConfiguration.needsApplying(configuration, current: current,
                                                       lastApplied: lastApplied) {
            lastApplied = nil
            try session.setCategory(configuration.category, mode: configuration.mode,
                                    options: configuration.options)
            lastApplied = configuration
        }
        try session.setActive(true)
    }
}
