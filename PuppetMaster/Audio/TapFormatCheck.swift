import Foundation

/// The precondition `AVAudioInputNode.installTap(onBus:bufferSize:format:)` asserts on,
/// restated in Swift so that failing it is a value we can branch on.
///
/// This exists because the AVFAudio version is not survivable. Handing `installTap` a
/// format that disagrees with the input hardware raises an `NSException` from inside
/// Objective-C — `required condition is false: format.sampleRate == hwFormat.sampleRate`
/// — and a Swift `do`/`catch` cannot contain that. The process aborts. So the check has
/// to happen *before* the call, and this is it.
///
/// Deliberately expressed in plain numbers rather than `AVAudioFormat`, so the rule can
/// be tested without any audio hardware. See `docs/MIC-CRASH.md`.
enum TapFormatCheck {

    /// Sample rates are floating point and come from two different reads of the hardware,
    /// so they are compared with a tolerance rather than for equality. A hair under a
    /// hertz apart is the same clock; 44,100 against 48,000 is not.
    static let sampleRateTolerance: Double = 1

    static func isUsable(tapSampleRate: Double,
                         tapChannels: UInt32,
                         hardwareSampleRate: Double,
                         hardwareChannels: UInt32) -> Bool {
        // A zero sample rate means there is no input behind the node at all — the state
        // the audio session is in before it has been upgraded for recording, and the one
        // the Simulator is in permanently.
        guard tapSampleRate > 0, hardwareSampleRate > 0 else { return false }
        guard tapChannels > 0, hardwareChannels > 0 else { return false }
        guard tapChannels == hardwareChannels else { return false }
        return abs(tapSampleRate - hardwareSampleRate) <= sampleRateTolerance
    }
}
