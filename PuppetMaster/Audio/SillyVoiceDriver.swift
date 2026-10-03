import Foundation

/// The puppet's mouth when there is no microphone.
///
/// A denied permission is a supported way to use this app, not an error state. Holding
/// Talk still makes the puppet mouth off — it just babbles to its own rhythm instead
/// of yours. Syllable lengths, peaks and gaps are all randomised, because anything
/// regular immediately reads as a machine rather than a character.
struct SillyVoiceDriver {

    /// A syllable that has just begun, for anything that wants to voice it.
    struct Syllable: Equatable {
        let duration: Double
        /// How wide the mouth opens, 0…1. Doubles as how loud to say it.
        let peak: Double
    }

    /// Set on the update a syllable starts, cleared on the next. Read it once per frame,
    /// right after `update(delta:)` — that is what keeps the sound on the mouth.
    private(set) var onset: Syllable?

    private var time: Double = 0
    private var isSpeaking = false
    private var syllableStart: Double = 0
    private var syllableDuration: Double = 0
    private var syllablePeak: Double = 0
    private var gapEnd: Double = 0

    mutating func reset() {
        time = 0
        isSpeaking = false
        syllableStart = 0
        syllableDuration = 0
        syllablePeak = 0
        gapEnd = 0
        onset = nil
    }

    /// Advance and return the current 0…1 jaw drive.
    mutating func update(delta: Double) -> Double {
        time += delta
        onset = nil

        if isSpeaking, time - syllableStart >= syllableDuration {
            isSpeaking = false
            gapEnd = time + Double.random(in: 0.04...0.17)
            // Roughly every fifth syllable, take a breath — that is where phrases come from.
            if Int.random(in: 0..<5) == 0 { gapEnd += Double.random(in: 0.22...0.5) }
        }

        if !isSpeaking, time >= gapEnd {
            isSpeaking = true
            syllableStart = time
            syllableDuration = Double.random(in: 0.10...0.26)
            syllablePeak = Double.random(in: 0.45...1.0)
            onset = Syllable(duration: syllableDuration, peak: syllablePeak)
        }

        guard isSpeaking, syllableDuration > 0 else { return 0 }

        // One syllable: snap open, close more slowly, never quite back to zero mid-word.
        let t = ((time - syllableStart) / syllableDuration).clamped(to: 0...1)
        let envelope = t < 0.3
            ? Easing.easeOut.apply(t / 0.3)
            : 1 - Easing.easeInOut.apply((t - 0.3) / 0.7) * 0.85

        return (syllablePeak * envelope).clamped(to: 0...1)
    }
}
