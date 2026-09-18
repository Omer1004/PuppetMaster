import Foundation

/// Keeps the puppet alive when nobody is touching anything.
///
/// This is the single most important piece of motion in the product. A still puppet
/// reads as a broken app; a breathing, blinking, gently-swaying one reads as a
/// creature that is waiting for you. It is never switched off — every other layer
/// composes on top of it.
///
/// The sway uses several sine waves at deliberately non-harmonic periods so the loop
/// never visibly repeats.
public struct IdleDriver: Sendable {

    private var time: Double = 0
    private var nextBlink: Double
    private var blinkProgress: Double = -1     // -1 = not blinking
    private var rng: SystemRandomNumberGenerator

    /// Scales the whole layer. Dropped to a fraction when Reduce Motion is on, rather
    /// than switched off — a completely motionless puppet is worse for everyone.
    public var intensity: Double = 1

    public init() {
        rng = SystemRandomNumberGenerator()
        nextBlink = Double.random(in: 1.5...4.0)
    }

    public mutating func update(delta: Double) {
        time += delta

        if blinkProgress >= 0 {
            blinkProgress += delta
            if blinkProgress > Self.blinkDuration {
                blinkProgress = -1
                nextBlink = time + Double.random(in: 2.0...6.5, using: &rng)
            }
        } else if time >= nextBlink {
            blinkProgress = 0
            // Occasionally a double blink. Irregularity is what stops it looking timed.
            if Bool.random(using: &rng) && Bool.random(using: &rng) {
                nextBlink = time + Self.blinkDuration + 0.12
            }
        }
    }

    public func apply(to pose: inout PuppetPose) {
        let k = intensity

        // Breathing: slow, and it moves the body as well as scaling it.
        let breathPhase = sin(time * 2 * .pi / 3.4)
        pose[.breath] = (breathPhase + 1) / 2
        pose.add(.bodyOffsetY, breathPhase * 2.2, weight: k)
        pose.add(.squash, breathPhase * 0.018, weight: k)

        // Weight shift. Three periods that do not divide into each other.
        pose.add(.bodyOffsetX, sin(time * 2 * .pi / 7.3) * 3.4, weight: k)
        pose.add(.bodyLean, sin(time * 2 * .pi / 5.7) * 0.030, weight: k)
        pose.add(.headTilt, sin(time * 2 * .pi / 4.3) * 0.032, weight: k)
        pose.add(.headTurn, sin(time * 2 * .pi / 9.1) * 0.12, weight: k)

        // Idle gaze wander — small, slow, and never quite centred.
        pose.add(.gazeX, sin(time * 2 * .pi / 6.1) * 0.18, weight: k)
        pose.add(.gazeY, sin(time * 2 * .pi / 8.7) * 0.12, weight: k)

        pose.add(.blink, blinkAmount)
    }

    /// Blink shape: snap shut, hold a frame, open slower. Real eyelids are not symmetric.
    private var blinkAmount: Double {
        guard blinkProgress >= 0 else { return 0 }
        let t = blinkProgress / Self.blinkDuration
        if t < 0.35 { return Easing.easeOut.apply(t / 0.35) }
        if t < 0.5 { return 1 }
        return 1 - Easing.easeInOut.apply((t - 0.5) / 0.5)
    }

    private static let blinkDuration: Double = 0.14
}
