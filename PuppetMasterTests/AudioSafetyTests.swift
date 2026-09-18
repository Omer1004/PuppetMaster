import Testing
@testable import PuppetMaster

/// The microphone crash on device came down to one precondition that AVFAudio asserts
/// on and Swift cannot catch. These tests cover the restatement of that precondition —
/// the only part of the audio layer that can be exercised without hardware, and the
/// part that decides whether the process aborts. See `docs/MIC-CRASH.md`.
@Suite("Tap format safety")
struct TapFormatCheckTests {

    @Test("A matching format is usable")
    func matching() {
        #expect(TapFormatCheck.isUsable(tapSampleRate: 48_000, tapChannels: 1,
                                        hardwareSampleRate: 48_000, hardwareChannels: 1))
    }

    /// The exact shape of the shipped crash: a tap installed while the session was still
    /// `.playback`, then used after it became `.playAndRecord` at a different rate.
    @Test("A stale sample rate is refused")
    func staleSampleRate() {
        #expect(!TapFormatCheck.isUsable(tapSampleRate: 44_100, tapChannels: 1,
                                         hardwareSampleRate: 48_000, hardwareChannels: 1))
    }

    @Test("A channel count mismatch is refused")
    func channelMismatch() {
        #expect(!TapFormatCheck.isUsable(tapSampleRate: 48_000, tapChannels: 2,
                                         hardwareSampleRate: 48_000, hardwareChannels: 1))
    }

    /// What the input node reports before the session has been upgraded for recording,
    /// and what it reports permanently in the Simulator.
    @Test("A zero sample rate is refused on either side")
    func zeroRate() {
        #expect(!TapFormatCheck.isUsable(tapSampleRate: 0, tapChannels: 1,
                                         hardwareSampleRate: 48_000, hardwareChannels: 1))
        #expect(!TapFormatCheck.isUsable(tapSampleRate: 48_000, tapChannels: 1,
                                         hardwareSampleRate: 0, hardwareChannels: 1))
    }

    @Test("Zero channels are refused on either side")
    func zeroChannels() {
        #expect(!TapFormatCheck.isUsable(tapSampleRate: 48_000, tapChannels: 0,
                                         hardwareSampleRate: 48_000, hardwareChannels: 0))
    }

    /// Two reads of the same clock can disagree in the last decimal place. That must not
    /// send a working microphone down the fallback path.
    @Test("A sub-hertz difference is still the same clock")
    func tolerance() {
        #expect(TapFormatCheck.isUsable(tapSampleRate: 48_000, tapChannels: 1,
                                        hardwareSampleRate: 48_000.4, hardwareChannels: 1))
        #expect(!TapFormatCheck.isUsable(tapSampleRate: 48_000, tapChannels: 1,
                                         hardwareSampleRate: 48_002, hardwareChannels: 1))
    }
}
