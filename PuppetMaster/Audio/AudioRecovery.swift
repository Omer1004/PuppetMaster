import Foundation

/// What a system audio event actually requires of us.
///
/// This exists because getting it wrong froze the app on device, twice, in two different
/// ways — and because it is the one part of audio recovery that can be tested without
/// hardware. The AVFoundation glue around it is untestable; this table is not.
///
/// ## The rule that matters
///
/// **An ordinary configuration change must not touch the audio session.**
///
/// Changing the session's category reconfigures the audio hardware, and reconfiguring
/// the hardware posts `AVAudioEngineConfigurationChange` to every running engine. So a
/// handler that responds to that notification by setting a category re-triggers itself,
/// forever. The notifications are delivered on the main queue, so the queue never drains
/// and the app freezes with no crash report — it is simply never given a turn to draw.
///
/// Both shipped versions of the microphone fix made this mistake:
///
/// - The first had `SoundBank` force the session back to `.playback` on every change.
///   The microphone immediately upgraded it again, and the two engines oscillated for
///   as long as the Talk button was held.
/// - The second "fixed" that by re-asserting whatever was intended instead — which
///   turned a two-party oscillation into a tight self-sustaining loop in one handler.
///
/// A third, quieter copy survived the fix for the second: the microphone's own handler
/// rebuilt itself through `start()`, which upgrades the session. That is why the rule is
/// now *enforced* rather than documented — see `handleConfigurationChange(_:)`.
///
/// A configuration change says the *graph* is invalid, never the session. The session is
/// already whatever it should be; that is what caused the notification in the first
/// place.
enum AudioRecovery {

    enum Event: Equatable, CaseIterable {
        /// The hardware was reconfigured: a route change, a category change, a sample
        /// rate change. The engine is stopped and its connections are invalid.
        case configurationChange

        /// A phone call, Siri or an alarm finished. The system deactivated our session
        /// when it began, so it has to be made active again.
        case interruptionEnded

        /// The audio server restarted. Every object obtained from it — the session's
        /// configuration, the engine, its nodes — is dead.
        case mediaServicesReset
    }

    /// Whether the `AVAudioEngine` object itself has to be replaced, rather than having
    /// its graph rebuilt in place.
    ///
    /// An exhaustive switch, not `event == .mediaServicesReset`: a new event must make
    /// someone decide, not quietly inherit "no".
    static func needsFreshEngine(after event: Event) -> Bool {
        switch event {
        case .configurationChange: false
        case .interruptionEnded:   false
        case .mediaServicesReset:  true
        }
    }

    /// Whether the audio session has to be configured again.
    ///
    /// Only when something outside this app took it away. Answering `true` for a plain
    /// configuration change is the freeze described above.
    static func needsSessionReassertion(after event: Event) -> Bool {
        switch event {
        case .configurationChange: false
        case .interruptionEnded:   true
        case .mediaServicesReset:  true
        }
    }

    /// Whether what `AVAudioSession` reports about its own category can still be
    /// believed.
    ///
    /// After a media services reset it cannot: the server that held the configuration
    /// is gone, and Apple's guidance is to configure the session from scratch. Skipping
    /// a category "the session already has" on the strength of a stale read-back would
    /// leave it in the default `.soloAmbient` — silenced by the ring/silent switch and
    /// interrupting other apps' audio. An interruption only deactivates the session; its
    /// category survives.
    static func sessionStateIsTrustworthy(after event: Event) -> Bool {
        switch event {
        case .configurationChange: true
        case .interruptionEnded:   true
        case .mediaServicesReset:  false
        }
    }

    // MARK: Enforcing the rule

    /// True while a configuration-change handler is running. `AudioSession` refuses to
    /// upgrade or re-apply anything while it is set.
    @MainActor private(set) static var isHandlingConfigurationChange = false

    /// Every `AVAudioEngineConfigurationChange` handler in the app runs inside this.
    ///
    /// A rule that has been broken three times by careful people is not one to leave to
    /// comments. Inside here, `AudioSession` refuses upgrades and re-assertions and logs
    /// a `fault` naming the mistake — the loop cannot start, and the attempt is visible.
    /// A downgrade to playback is still allowed: it is how a failed rebuild hands the
    /// session back, and it cannot sustain a loop on its own, because once the session
    /// is `.playback` the next one is skipped.
    @MainActor static func handleConfigurationChange(_ body: () -> Void) {
        let outer = isHandlingConfigurationChange
        isHandlingConfigurationChange = true
        defer { isHandlingConfigurationChange = outer }
        body()
    }
}
