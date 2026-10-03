import Foundation
import Testing
@testable import PuppetMaster

/// Voice effects are mostly DSP over plain arrays, so — unlike the microphone they feed
/// on — almost all of them can be tested here.
@Suite("Voice effects")
struct VoiceEffectTests {

    @Test("Off keeps nothing and stays silent; every other effect does both")
    func offIsOff() {
        #expect(!VoiceEffect.off.repeatsYou)
        #expect(!VoiceEffect.off.babblesAloud)
        for effect in VoiceEffect.allCases where effect != .off {
            #expect(effect.repeatsYou)
            #expect(effect.babblesAloud)
        }
    }

    /// `AVAudioUnitTimePitch.pitch` accepts −2400…2400 cents.
    @Test("Every pitch shift is inside what the time-pitch unit accepts")
    func shiftsAreInRange() {
        for effect in VoiceEffect.allCases {
            #expect(abs(effect.repeatSemitones * 100) <= 2400)
        }
    }

    @Test("Squeaky is higher than Rumbly, both repeated and babbled")
    func squeakyIsHigherThanRumbly() {
        #expect(VoiceEffect.squeaky.repeatSemitones > VoiceEffect.rumbly.repeatSemitones)
        #expect(VoiceEffect.squeaky.babblePitch > VoiceEffect.rumbly.babblePitch)
    }

    @Test("Only the robot is monotone and ring-modulated")
    func robotIsTheRobot() {
        for effect in VoiceEffect.allCases {
            #expect(effect.isMonotone == (effect == .robot))
            #expect((effect.ringModulationHz != nil) == (effect == .robot))
        }
    }
}

@Suite("Repeating a take")
struct RepeatTakeTests {

    private let rate = 48_000.0

    /// A tone with silence either side, the shape of a short spoken phrase.
    private func phrase(seconds: Double, leadingSilence: Double = 0.4,
                        trailingSilence: Double = 0.6) -> [Float] {
        let quiet = { (s: Double) in [Float](repeating: 0, count: Int(s * self.rate)) }
        let voiced = (0..<Int(seconds * rate)).map { i in
            Float(0.3 * sin(2 * .pi * 220 * Double(i) / rate))
        }
        return quiet(leadingSilence) + voiced + quiet(trailingSilence)
    }

    @Test("With the effect off, nothing is prepared")
    func offPreparesNothing() {
        #expect(VoiceEffectDSP.prepare(phrase(seconds: 1), sampleRate: rate, effect: .off) == nil)
    }

    @Test("Silence is not repeated")
    func silenceIsNotRepeated() {
        let silence = [Float](repeating: 0, count: Int(rate))
        #expect(VoiceEffectDSP.prepare(silence, sampleRate: rate, effect: .squeaky) == nil)
    }

    @Test("A tap on the button is not repeated")
    func tooShortIsNotRepeated() {
        #expect(VoiceEffectDSP.prepare(phrase(seconds: 0.1), sampleRate: rate,
                                       effect: .squeaky) == nil)
    }

    /// The puppet should start talking promptly, not wait out the pause before you
    /// spoke — and the result should be in the sound bank's format.
    @Test("A take is trimmed, converted to the output rate, and no longer than the cap")
    func takeIsTrimmedAndConverted() throws {
        let take = try #require(VoiceEffectDSP.prepare(phrase(seconds: 1), sampleRate: rate,
                                                       effect: .rumbly))
        // One second of voice plus the 60 ms of air kept either side.
        #expect(abs(take.duration - 1.12) < 0.02)

        let long = try #require(VoiceEffectDSP.prepare(phrase(seconds: 12), sampleRate: rate,
                                                       effect: .rumbly))
        #expect(long.duration <= VoiceEffectDSP.maximumDuration + 0.001)
    }

    @Test("The mouth moves while the take is voiced and is shut after it ends")
    func envelopeFollowsTheTake() throws {
        let take = try #require(VoiceEffectDSP.prepare(phrase(seconds: 1), sampleRate: rate,
                                                       effect: .squeaky))
        #expect(take.jaw(at: 0.5) > 0.3)
        #expect(take.jaw(at: take.duration + 0.5) == 0)
        #expect(take.jaw(at: -1) == 0)
        #expect(take.envelope.allSatisfy { (0...1).contains($0) })
    }

    /// A take cut at an arbitrary sample starts with a click otherwise.
    @Test("Both ends fade, so playback does not click")
    func edgesFade() throws {
        let take = try #require(VoiceEffectDSP.prepare(phrase(seconds: 1), sampleRate: rate,
                                                       effect: .squeaky))
        #expect(take.samples.first == 0)
        #expect(abs(take.samples.last ?? 1) < 0.001)
    }

    @Test("Resampling scales the length and leaves a same-rate signal alone")
    func resampling() {
        let one = [Float](repeating: 0.5, count: 48_000)
        #expect(VoiceEffectDSP.resample(one, from: 48_000, to: 48_000) == one)
        let converted = VoiceEffectDSP.resample(one, from: 48_000, to: 44_100)
        #expect(abs(converted.count - 44_100) <= 1)
        #expect(converted.allSatisfy { abs($0 - 0.5) < 0.0001 })
        #expect(VoiceEffectDSP.resample([], from: 48_000, to: 44_100).isEmpty)
    }

    @Test("Ring modulation keeps the length and starts at zero")
    func ringModulation() {
        let flat = [Float](repeating: 1, count: 1000)
        let modulated = VoiceEffectDSP.ringModulate(flat, sampleRate: 44_100, frequency: 55)
        #expect(modulated.count == flat.count)
        #expect(modulated[0] == 0)
        #expect(modulated.allSatisfy { abs($0) <= 1 })
    }

    @Test("The jaw mapping is shut in silence and open when loud")
    func jawMapping() {
        #expect(JawLevel.from(rms: 0) == 0)
        #expect(JawLevel.from(rms: 0.001) == 0)
        #expect(JawLevel.from(rms: 0.5) == 1)
    }
}

@Suite("Silly voice out loud")
struct BabbleTests {

    /// The sound is started on the onset, so one onset per syllable is what keeps the
    /// voice on the mouth — two would double a syllable, none would drop one.
    @Test("Each syllable is announced exactly once, on the frame it starts")
    func onsetOncePerSyllable() {
        var driver = SillyVoiceDriver()
        var onsets = 0
        var wasOpen = false
        var openings = 0
        for _ in 0..<1200 {
            let level = driver.update(delta: 1.0 / 60)
            if driver.onset != nil { onsets += 1 }
            let open = level > 0
            if open && !wasOpen { openings += 1 }
            wasOpen = open
        }
        #expect(onsets > 10)
        // Every opening of the mouth had an onset. (A syllable can begin straight after
        // another without the level touching zero, so there can be more onsets.)
        #expect(onsets >= openings)
    }

    @Test("An onset is cleared on the next frame and by a reset")
    func onsetIsTransient() {
        var driver = SillyVoiceDriver()
        var found = false
        for _ in 0..<600 {
            _ = driver.update(delta: 1.0 / 60)
            if driver.onset != nil {
                found = true
                _ = driver.update(delta: 0.0001)
                #expect(driver.onset == nil)
                break
            }
        }
        #expect(found)
        driver.reset()
        #expect(driver.onset == nil)
    }

    @Test("A babbled syllable starts and ends silent, for every effect")
    @MainActor
    func syllableHasNoClicks() {
        for effect in VoiceEffect.allCases where effect.babblesAloud {
            let samples = SoundBank.renderSyllable(duration: 0.16, pitch: 1, contour: 0,
                                                   effect: effect)
            #expect(!samples.isEmpty)
            #expect(abs(samples.first ?? 1) < 0.01)
            #expect(abs(samples.last ?? 1) < 0.01)
        }
    }
}

@Suite("Take buffer")
struct TakeBufferTests {

    private func feed(_ buffer: TakeBuffer, _ samples: [Float]) {
        samples.withUnsafeBufferPointer { buffer.append($0.baseAddress!, count: $0.count) }
    }

    @Test("Keeps what it is given, hands it over once, then forgets it")
    func drainOnce() {
        let buffer = TakeBuffer(capacity: 100)
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [0.1, 0.2, 0.3])
        let first = buffer.drain()
        #expect(first.samples == [0.1, 0.2, 0.3])
        #expect(first.sampleRate == 48_000)
        #expect(buffer.drain().samples.isEmpty)
    }

    /// The privacy promise: with no repeating effect chosen, nothing is held.
    @Test("Keeps nothing when not asked to")
    func keepsNothingWhenOff() {
        let buffer = TakeBuffer(capacity: 100)
        buffer.begin(sampleRate: 48_000, keep: false)
        feed(buffer, [0.1, 0.2, 0.3])
        #expect(buffer.drain().samples.isEmpty)
    }

    @Test("Stops at its capacity rather than overrunning")
    func capacity() {
        let buffer = TakeBuffer(capacity: 4)
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [1, 2, 3])
        feed(buffer, [4, 5, 6])
        #expect(buffer.drain().samples == [1, 2, 3, 4])
    }

    /// Stitching two rates together would replay half the take at the wrong speed.
    @Test("A rebuild at a different rate abandons the take")
    func rateChangeAbandons() {
        let buffer = TakeBuffer(capacity: 100)
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [1, 2])
        buffer.begin(sampleRate: 16_000, keep: true)
        feed(buffer, [3])
        #expect(buffer.drain().samples.isEmpty)
    }

    /// Once abandoned, a third rebuild must not quietly start a new take — the puppet
    /// would repeat only the end of what was said.
    @Test("An abandoned take stays abandoned until the next press")
    func abandonedStaysAbandoned() {
        let buffer = TakeBuffer(capacity: 100)
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [1, 2])
        buffer.begin(sampleRate: 16_000, keep: true)
        buffer.begin(sampleRate: 16_000, keep: true)
        feed(buffer, [3])
        #expect(buffer.drain().samples.isEmpty)

        // The next press starts clean.
        buffer.begin(sampleRate: 16_000, keep: true)
        feed(buffer, [4])
        #expect(buffer.drain().samples == [4])
    }

    @Test("A rebuild at the same rate continues the take")
    func sameRateContinues() {
        let buffer = TakeBuffer(capacity: 100)
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [1, 2])
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [3])
        #expect(buffer.drain().samples == [1, 2, 3])
    }

    @Test("Discard forgets the take")
    func discard() {
        let buffer = TakeBuffer(capacity: 100)
        buffer.begin(sampleRate: 48_000, keep: true)
        feed(buffer, [1, 2])
        buffer.discard()
        #expect(buffer.drain().samples.isEmpty)
    }
}
