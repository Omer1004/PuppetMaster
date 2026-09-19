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
    static func needsFreshEngine(after event: Event) -> Bool {
        event == .mediaServicesReset
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
}
