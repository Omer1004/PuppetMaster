import Foundation

/// The loudness-to-jaw mapping, shared by the live microphone and a repeated take so the
/// puppet's mouth moves the same way for both.
enum JawLevel {
    /// Quietest level treated as silence. Below this the mouth stays shut, so room
    /// noise does not leave the puppet permanently mumbling.
    /// Computed rather than stored: `from(rms:)` runs on the audio thread, and a lazily
    /// initialised static is a `swift_once` — a lock — on first touch.
    static var floorDB: Double { -52 }
    static var ceilingDB: Double { -12 }

    /// RMS (0…1) to jaw drive (0…1). Allocation-free: called on the audio thread.
    static func from(rms: Double) -> Double {
        let db = rms > 0 ? 20 * log10(rms) : -160
        let normalised = ((db - floorDB) / (ceilingDB - floorDB)).clamped(to: 0...1)
        // Slight curve: quiet speech should still open the mouth a useful amount.
        return pow(normalised, 0.75)
    }
}

/// A microphone take, prepared for the puppet to repeat.
struct PreparedTake: Sendable, Equatable {
    /// Mono, at `VoiceEffectDSP.outputRate`, peak-normalised, effect applied.
    let samples: [Float]
    /// Jaw drive, one value per `envelopeStep` seconds of `samples`.
    let envelope: [Double]
    let effect: VoiceEffect

    var duration: Double { Double(samples.count) / VoiceEffectDSP.outputRate }

    /// Jaw drive at `time` seconds into the take.
    func jaw(at time: Double) -> Double {
        guard !envelope.isEmpty, time >= 0 else { return 0 }
        let index = Int(time / VoiceEffectDSP.envelopeInterval)
        return index < envelope.count ? envelope[index] : 0
    }
}

/// Offline processing for "the puppet repeats you". Pure maths over `[Float]`, so all of
/// it is testable without a microphone — which matters, because the microphone path
/// cannot run in the Simulator at all.
///
/// Pitch shifting is *not* done here. It happens at playback in `AVAudioUnitTimePitch`,
/// which keeps the duration, so the envelope computed here stays on the words.
enum VoiceEffectDSP {

    /// The sound bank's format. Takes are converted to it so they share its graph.
    static let outputRate = Synth.sampleRate
    /// Envelope resolution. Finer than a frame, so the jaw never visibly steps.
    static let envelopeStep = 1.0 / 120
    /// Samples per envelope value, and the exact time each one covers. Rounded once
    /// and used on both sides, so reading the envelope back cannot drift off the words.
    static var envelopeWindow: Int { max(1, Int(envelopeStep * outputRate)) }
    static var envelopeInterval: Double { Double(envelopeWindow) / outputRate }
    /// Takes shorter than this, after trimming, are not repeated — a tap on the button
    /// is not something to say back.
    static let minimumDuration = 0.3
    /// Longer takes are cut here. Also the size of the buffer the microphone fills.
    static let maximumDuration = 8.0

    /// Everything from raw microphone samples to a take ready to play, or `nil` if there
    /// is nothing worth repeating.
    static func prepare(_ raw: [Float], sampleRate: Double, effect: VoiceEffect) -> PreparedTake? {
        guard effect.repeatsYou, sampleRate > 0, !raw.isEmpty else { return nil }
        var samples = trimSilence(raw, sampleRate: sampleRate)
        guard Double(samples.count) / sampleRate >= minimumDuration else { return nil }

        samples = resample(samples, from: sampleRate, to: outputRate)
        let cap = Int(maximumDuration * outputRate)
        if samples.count > cap { samples.removeLast(samples.count - cap) }
        if let hz = effect.ringModulationHz {
            samples = ringModulate(samples, sampleRate: outputRate, frequency: hz)
        }
        samples = fadeEdges(Synth.normalised(samples, peak: 0.85), sampleRate: outputRate)
        return PreparedTake(samples: samples,
                            envelope: envelope(samples, sampleRate: outputRate),
                            effect: effect)
    }

    /// Linear-interpolation resampling. Crude by studio standards, inaudible here: the
    /// source is speech from a phone microphone, and it is about to be pitch-shifted.
    static func resample(_ samples: [Float], from source: Double, to target: Double) -> [Float] {
        guard source > 0, target > 0, !samples.isEmpty else { return [] }
        guard source != target else { return samples }
        let ratio = source / target
        let count = max(1, Int((Double(samples.count) / ratio).rounded(.down)))
        var out = [Float](repeating: 0, count: count)
        let last = samples.count - 1
        for i in 0..<count {
            let position = Double(i) * ratio
            let index = min(Int(position), last)
            let next = min(index + 1, last)
            let fraction = Float(position - Double(index))
            out[i] = samples[index] + (samples[next] - samples[index]) * fraction
        }
        return out
    }

    /// Multiply by a sine wave. At a few tens of hertz this is the robot voice from every
    /// film you have seen.
    static func ringModulate(_ samples: [Float], sampleRate: Double, frequency: Double) -> [Float] {
        guard sampleRate > 0 else { return samples }
        let step = 2 * Double.pi * frequency / sampleRate
        var out = samples
        for i in 0..<out.count {
            out[i] *= Float(sin(Double(i) * step))
        }
        return out
    }

    /// Drop the silence before the first word and after the last, so the puppet starts
    /// talking promptly and does not hold its mouth shut for the time it took you to
    /// let go of the button.
    static func trimSilence(_ samples: [Float], sampleRate: Double,
                            threshold: Float = 0.01) -> [Float] {
        guard let first = samples.firstIndex(where: { abs($0) > threshold }),
              let last = samples.lastIndex(where: { abs($0) > threshold }) else { return [] }
        // A little air either side, so consonants are not clipped.
        let pad = Int(0.06 * sampleRate)
        let start = max(0, first - pad)
        let end = min(samples.count - 1, last + pad)
        return Array(samples[start...end])
    }

    /// Short fades at both ends. A take cut at an arbitrary sample starts and ends with
    /// a click otherwise.
    static func fadeEdges(_ samples: [Float], sampleRate: Double, seconds: Double = 0.012) -> [Float] {
        let length = min(Int(seconds * sampleRate), samples.count / 2)
        guard length > 0 else { return samples }
        var out = samples
        for i in 0..<length {
            let gain = Float(i) / Float(length)
            out[i] *= gain
            out[out.count - 1 - i] *= gain
        }
        return out
    }

    /// Jaw drive over time, from the same loudness mapping the live microphone uses.
    static func envelope(_ samples: [Float], sampleRate: Double) -> [Double] {
        // Always called with `outputRate`; the window is derived from it so that
        // `PreparedTake.jaw(at:)` reads back at exactly the spacing written here.
        let window = sampleRate == outputRate ? envelopeWindow : max(1, Int(envelopeStep * sampleRate))
        var levels: [Double] = []
        levels.reserveCapacity(samples.count / window + 1)
        var start = 0
        while start < samples.count {
            let end = min(start + window, samples.count)
            var sum: Float = 0
            for i in start..<end { sum += samples[i] * samples[i] }
            let rms = Double((sum / Float(end - start)).squareRoot())
            levels.append(JawLevel.from(rms: rms))
            start = end
        }
        return levels
    }
}
