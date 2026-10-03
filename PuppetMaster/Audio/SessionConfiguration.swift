import AVFoundation

/// A category, mode and option set the app can ask the audio session for.
///
/// Split out of `AudioSession` so the one decision that stops a redundant
/// reconfiguration — `needsApplying` — can be tested without touching the real session.
struct SessionConfiguration: Equatable {
    var category: AVAudioSession.Category
    var mode: AVAudioSession.Mode
    var options: AVAudioSession.CategoryOptions

    /// Output only. See `AudioSession.Intent.playback` for why this is not
    /// `.playAndRecord`.
    static var playback: SessionConfiguration {
        SessionConfiguration(category: .playback, mode: .default, options: [.mixWithOthers])
    }

    /// Output and input. Bluetooth input is deliberately not requested — see
    /// `AudioSession.activateForRecording()`.
    static var recording: SessionConfiguration {
        SessionConfiguration(category: .playAndRecord, mode: .default,
                             options: [.defaultToSpeaker, .mixWithOthers])
    }

    /// Whether asking for `requested` would change anything.
    ///
    /// Setting a configuration the session already has is **not** free: it still
    /// reconfigures the audio hardware and posts `AVAudioEngineConfigurationChange` to
    /// every running engine. So this errs towards "no" — but only where the answer is
    /// knowable:
    ///
    /// - A different category or mode always needs applying. The old check ignored the
    ///   mode, so a mode changed underneath us was never put back.
    /// - Identical options do not.
    /// - Options that differ *only* because iOS reported them back normalised — a bit
    ///   added or dropped from what was asked — do not either, provided the last thing
    ///   this app successfully applied was exactly `requested`. The old check compared
    ///   the read-back to the request bit-for-bit, so a normalised read-back meant every
    ///   redundant request reconfigured the hardware, and the guard against the freeze
    ///   was only as good as the system's bookkeeping.
    static func needsApplying(_ requested: SessionConfiguration,
                              current: SessionConfiguration,
                              lastApplied: SessionConfiguration?) -> Bool {
        guard current.category == requested.category,
              current.mode == requested.mode else { return true }
        if current.options == requested.options { return false }
        return lastApplied != requested
    }
}
