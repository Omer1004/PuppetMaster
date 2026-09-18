import Foundation

/// Keeps the puppet alive when nobody is touching anything.
///
/// This is the single most important piece of motion in the product. A still puppet
/// reads as a broken app; a breathing, blinking, gently-swaying one reads as a creature
/// that is waiting for you. It is never switched off — every other layer composes on
/// top of it.
///
/// It is also where most of a character's personality actually lives. The four cast
/// members would still read as different creatures if they were identical shapes,
/// because `Personality` changes how fast they breathe, how often they blink and how
/// much they fidget. Geometry distinguishes species; timing distinguishes temperament.
///
/// The sway uses several sine waves at deliberately non-harmonic periods, so the loop
/// never visibly repeats.
public struct IdleDriver: Sendable {

    /// Whose idle this is. Swapped whenever the character changes.
    public var personality = CharacterDescriptor.Personality()

    /// Scales the whole layer. Dropped to a fraction when Reduce Motion is on, rather
    /// than switched off — a completely motionless puppet reads as a crash.
    public var intensity: Double = 1

    private var time: Double = 0
    private var nextBlink: Double
    private var blinkProgress: Double = -1     // -1 = not blinking
    /// Carried across the blink rather than encoded in `nextBlink`, which the
    /// completion branch overwrites.
    private var pendingDoubleBlink = false
    private var rng = SystemRandomNumberGenerator()

    public init() {
        nextBlink = Double.random(in: 1.5...4.0)
    }

    /// Adopt a new character's timing. The breathing phase deliberately carries over —
    /// restarting it mid-inhale produces a visible hitch at the moment of the swap, and
    /// nobody can tell where in a breath a new character "should" start.
    public mutating func adopt(_ personality: CharacterDescriptor.Personality) {
        self.personality = personality
        blinkProgress = -1
        pendingDoubleBlink = false
        nextBlink = time + Double.random(in: personality.blinkInterval.range, using: &rng)
    }

    public mutating func update(delta: Double) {
        time += delta
        let blinkDuration = Self.baseBlinkDuration / max(personality.blinkSpeed, 0.1)

        if blinkProgress >= 0 {
            blinkProgress += delta
            if blinkProgress > blinkDuration {
                blinkProgress = -1
                if pendingDoubleBlink {
                    pendingDoubleBlink = false
                    nextBlink = time + 0.1        // the second half of a double blink
                } else {
                    nextBlink = time + Double.random(in: personality.blinkInterval.range,
                                                     using: &rng)
                }
            }
        } else if time >= nextBlink {
            blinkProgress = 0
            // Sometimes a double blink. Irregularity is what stops it looking timed.
            pendingDoubleBlink =
                Double.random(in: 0...1, using: &rng) < personality.doubleBlinkChance
        }
    }

    public func apply(to pose: inout PuppetPose) {
        let k = intensity
        let p = personality

        // Breathing: slow, and it moves the body as well as scaling it.
        let breathPhase = sin(time * 2 * .pi / max(p.breathPeriod, 0.2))
        pose[.breath] = (breathPhase + 1) / 2
        pose.add(.bodyOffsetY, breathPhase * 2.2 * p.breathAmount, weight: k)
        pose.add(.squash, breathPhase * 0.018 * p.breathAmount, weight: k)

        // Weight shift. Three periods that do not divide into each other.
        pose.add(.bodyOffsetX, sin(time * 2 * .pi / 7.3) * 3.4 * p.swayAmount, weight: k)
        pose.add(.bodyLean, sin(time * 2 * .pi / 5.7) * 0.030 * p.swayAmount, weight: k)
        pose.add(.headTilt, sin(time * 2 * .pi / 4.3) * 0.032 * p.headTiltAmount, weight: k)
        pose.add(.headTurn, sin(time * 2 * .pi / 9.1) * 0.12 * p.headTiltAmount, weight: k)

        // Idle gaze wander — small, slow, and never quite centred.
        pose.add(.gazeX, sin(time * 2 * .pi / 6.1) * 0.18 * p.gazeWander, weight: k)
        pose.add(.gazeY, sin(time * 2 * .pi / 8.7) * 0.12 * p.gazeWander, weight: k)

        pose.add(.blink, blinkAmount)
    }

    /// Blink shape: snap shut, hold a frame, open more slowly. Real eyelids are not
    /// symmetric, and a symmetric blink looks like a shutter.
    private var blinkAmount: Double {
        guard blinkProgress >= 0 else { return 0 }
        let duration = Self.baseBlinkDuration / max(personality.blinkSpeed, 0.1)
        let t = blinkProgress / duration
        if t < 0.35 { return Easing.easeOut.apply(t / 0.35) }
        if t < 0.5 { return 1 }
        return 1 - Easing.easeInOut.apply((t - 0.5) / 0.5)
    }

    private static let baseBlinkDuration: Double = 0.14
}
