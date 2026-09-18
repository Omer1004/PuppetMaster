import Foundation

/// Eases the face between held expressions.
///
/// Holds a smoothed value for every channel any expression touches, so switching from
/// Silly to Happy glides instead of cutting — and so channels the new expression does
/// not mention ease back to rest rather than sticking.
public struct ExpressionLayer: Sendable {

    /// Union of channels used by any expression. Anything outside this set is left
    /// entirely to idle, actions and live drivers.
    private static let ownedChannels: Set<PoseChannel> = {
        var set = Set<PoseChannel>()
        for expression in Expression.allCases { set.formUnion(expression.targets.keys) }
        return set
    }()

    private var current: [PoseChannel: Double] = [:]
    public private(set) var expression: Expression = .neutral

    /// Seconds to cover most of the distance to a new expression. Short enough to feel
    /// like a reaction, long enough not to look like a jump cut.
    public var transition: Double = 0.16

    public init() {
        for channel in Self.ownedChannels { current[channel] = PuppetPose.neutral[channel] }
        setImmediately(.neutral)
    }

    public mutating func set(_ expression: Expression) { self.expression = expression }

    public mutating func setImmediately(_ expression: Expression) {
        self.expression = expression
        let targets = expression.targets
        for channel in Self.ownedChannels {
            current[channel] = targets[channel] ?? PuppetPose.neutral[channel]
        }
    }

    public mutating func update(delta: Double) {
        let targets = expression.targets
        let alpha = transition > 0 ? 1 - exp(-delta / transition) : 1
        for channel in Self.ownedChannels {
            let target = targets[channel] ?? PuppetPose.neutral[channel]
            let value = current[channel] ?? target
            current[channel] = value + (target - value) * alpha
        }
    }

    /// Channels an expression genuinely owns. Everything else it merely nudges.
    ///
    /// This distinction is load-bearing. `ownedChannels` is the *union* over all
    /// expressions, so if posture channels were overridden here, every expression —
    /// including Neutral — would flatten them to a constant. That silently killed the
    /// idle breathing: Surprised declares `bodyOffsetY`, so all four expressions were
    /// pinning it to zero every frame and the puppet stopped moving at rest.
    private static let facialChannels: Set<PoseChannel> =
        [.mouthSmile, .browLift, .browAngle, .tongueOut]

    public func apply(to pose: inout PuppetPose) {
        for (channel, value) in current {
            if Self.facialChannels.contains(channel) {
                pose.override(channel, value)
            } else {
                // Postural and live-driven channels get a *displacement* from rest, so
                // breathing, actions and the microphone all survive underneath. Surprised
                // opens the mouth a little; your voice still opens it the rest of the way.
                pose.add(channel, value - PuppetPose.neutral[channel])
            }
        }
    }
}
