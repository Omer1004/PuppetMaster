import Foundation

/// Live, continuously-varying input: the microphone and the aim drag.
public struct LiveInputs: Sendable {
    /// 0…1 loudness from the microphone (or the fallback driver when the mic is off).
    public var jawDrive: Double = 0
    /// Where the puppet is being told to look, in normalised stage coordinates.
    /// `nil` means nobody is aiming and the eyes should drift back to idle.
    public var aim: SIMD2<Double>?

    public init() {}
}

/// Composes one frame of puppet motion out of four layers.
///
///     idle          breathing, blinking, sway        always on
///   + expression    the held face                    eased
///   + actions       whatever is currently performing  weighted, overlapping
///   + live          microphone jaw, aim              additive
///   = pose
///
/// Order is the semantic. Because every layer writes into the same pose rather than
/// competing for ownership of it, the puppet can be happy, mid-wave, talking and
/// breathing at the same instant — which is the difference between a creature and a
/// menu of canned clips.
///
/// Deliberately a pure value type with no framework imports: the entire feel of the
/// product can be unit-tested in milliseconds, with no screen, simulator or microphone.
public struct PoseBlender: Sendable {

    public var idle = IdleDriver()
    public var expression = ExpressionLayer()
    public var actions = ActionScheduler()
    public var live = LiveInputs()

    private var jawSmoother = Smoother(attack: 0.022, release: 0.085)
    private var aimX = Smoother(attack: 0.09, release: 0.22)
    private var aimY = Smoother(attack: 0.09, release: 0.22)
    private var aimWeight = Smoother(attack: 0.10, release: 0.45)

    private var hairVelocity: Double = 0
    private var hairOffset: Double = 0
    private var previousHeadX: Double = 0

    public init() {}

    /// Advance every layer and produce the frame.
    public mutating func tick(delta: Double) -> (pose: PuppetPose, cues: ActionScheduler.Cues) {
        let delta = delta.clamped(to: 0...0.1)   // a stall must not teleport the puppet

        idle.update(delta: delta)
        expression.update(delta: delta)
        let cues = actions.update(delta: delta)

        jawSmoother.update(target: live.jawDrive.clamped(to: 0...1), delta: delta)
        aimWeight.update(target: live.aim == nil ? 0 : 1, delta: delta)
        if let aim = live.aim {
            aimX.update(target: aim.x.clamped(to: -1...1), delta: delta)
            aimY.update(target: aim.y.clamped(to: -1...1), delta: delta)
        }

        var pose = PuppetPose.neutral
        idle.apply(to: &pose)
        expression.apply(to: &pose)
        actions.apply(to: &pose)
        applyLive(to: &pose)
        applyHairLag(to: &pose, delta: delta)

        pose.clampToLimits()
        return (pose, cues)
    }

    private mutating func applyLive(to pose: inout PuppetPose) {
        // Speech opens the mouth on top of whatever the face is already doing.
        pose.add(.jawOpen, jawSmoother.value)
        // A talking puppet also moves its head a little; a jaw alone looks like a hinge.
        pose.add(.headNod, jawSmoother.value * -0.12)
        pose.add(.bodyOffsetY, jawSmoother.value * 1.6)

        let w = aimWeight.value
        guard w > 0.001 else { return }
        pose.override(.gazeX, aimX.value, weight: w)
        pose.override(.gazeY, aimY.value, weight: w)
        // The head follows the eyes part of the way. Eyes lead, head trails — that
        // ordering is what makes a look feel intentional rather than robotic.
        pose.add(.headTurn, aimX.value * 0.55 * w)
        pose.add(.headTilt, aimX.value * 0.10 * w)
        pose.add(.headNod, aimY.value * 0.45 * w)
    }

    /// Secondary motion for the hair tuft: it lags behind the head and overshoots when
    /// the head stops. Cheap spring, disproportionate charm.
    private mutating func applyHairLag(to pose: inout PuppetPose, delta: Double) {
        guard delta > 0 else { pose[.hairLag] = hairOffset; return }

        let headX = pose[.bodyOffsetX] * 0.02 + pose[.headTilt] * 2.2 + pose[.headTurn] * 0.9
        let headVelocity = (headX - previousHeadX) / delta
        previousHeadX = headX

        let stiffness = 120.0, damping = 13.0
        let force = -stiffness * hairOffset - damping * hairVelocity - headVelocity * 0.35
        hairVelocity += force * delta
        hairOffset += hairVelocity * delta
        hairOffset = hairOffset.clamped(to: -1.5...1.5)

        pose[.hairLag] = hairOffset
    }
}
