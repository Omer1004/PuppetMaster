import Foundation

/// How the puppet sounds when it talks.
///
/// One choice drives two features, because to the performer they are one idea — "what
/// does my puppet's voice sound like":
///
/// - **Silly Voice** (no microphone) babbles *out loud* in this voice, one synthesised
///   syllable per mouth movement. With `.off` it stays silent and only the mouth moves,
///   as it always has.
/// - **Microphone** takes are repeated back by the puppet in this voice after the Talk
///   button comes up. With `.off` nothing is kept: the microphone is measured for
///   loudness and discarded frame by frame, exactly as before.
///
/// Pure data. The audio layer turns it into DSP; nothing here knows about AVFoundation.
public enum VoiceEffect: String, CaseIterable, Sendable, Codable, Identifiable {
    case off
    case squeaky
    case rumbly
    case robot

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off:     "Off"
        case .squeaky: "Squeaky"
        case .rumbly:  "Rumbly"
        case .robot:   "Robot"
        }
    }

    public var symbol: String {
        switch self {
        case .off:     "speaker.slash"
        case .squeaky: "bird"
        case .rumbly:  "tortoise"
        case .robot:   "cpu"
        }
    }

    /// One line for the picker. Says plainly what happens to the microphone, because the
    /// performer is often an adult deciding for a child.
    public var summary: String {
        switch self {
        case .off:     "The mouth follows your voice. Nothing is kept."
        case .squeaky: "High and fast. The puppet repeats what you said."
        case .rumbly:  "Low and slow. The puppet repeats what you said."
        case .robot:   "Buzzy and flat. The puppet repeats what you said."
        }
    }

    /// Whether a microphone take is held in memory so the puppet can repeat it.
    public var repeatsYou: Bool { self != .off }

    /// Whether Silly Voice is audible.
    public var babblesAloud: Bool { self != .off }

    /// Pitch shift for a repeated take, in semitones. Duration is preserved, so the
    /// puppet's mouth stays on the words.
    public var repeatSemitones: Double {
        switch self {
        case .off:     0
        case .squeaky: 7
        case .rumbly:  -6
        case .robot:   -2
        }
    }

    /// Multiplies the babble's base pitch, on top of the character's own voice — so
    /// Pip on Rumbly is still higher than Bramble on Rumbly.
    public var babblePitch: Double {
        switch self {
        case .off:     1
        case .squeaky: 1.7
        case .rumbly:  0.55
        case .robot:   1.0
        }
    }

    /// Ring-modulation frequency in hertz, or `nil` for none. The classic robot voice is
    /// nothing more than the signal multiplied by a low sine wave.
    public var ringModulationHz: Double? {
        switch self {
        case .robot: 55
        default:     nil
        }
    }

    /// A robot does not inflect. Every other voice rises and falls a little per
    /// syllable, because a flat babble reads as a machine — which is the point here.
    public var isMonotone: Bool { self == .robot }
}
