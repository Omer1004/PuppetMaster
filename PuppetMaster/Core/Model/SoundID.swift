import Foundation

/// The sounds the puppet can make.
///
/// Named by what they *are*, not by which action uses them, so a new action can reach
/// for an existing sound. Every one is synthesised at runtime (see `SoundBank`) — there
/// are no audio files to commission, license, or ship.
public enum SoundID: String, Sendable, CaseIterable, Codable {
    case pop        // light, upward — a small thing happening
    case boing      // launch
    case thud       // landing, falling over
    case whoosh     // a limb moving fast
    case giggle     // laughing
    case chime      // celebration, success
    case tick       // small punctuation: a nod, a blink of attention
    case sneeze
    case yawn
    case squeak     // being poked
    case tap        // UI
}

/// A sound fired at a point in an action's timeline.
public struct SoundCue: Sendable, Codable, Equatable {
    public let time: Double
    public let sound: SoundID
    /// Multiplies the character's own voice pitch. Use sparingly — most variation
    /// should come from the character, not the action.
    public let pitch: Double

    public init(_ time: Double, _ sound: SoundID, pitch: Double = 1) {
        self.time = time
        self.sound = sound
        self.pitch = pitch
    }
}
