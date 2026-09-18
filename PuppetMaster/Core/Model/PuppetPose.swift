import Foundation

/// Every animatable property of a puppet.
///
/// Renderers bind these to whatever they draw with. Nothing outside the renderer
/// knows whether a channel ends up as a sprite rotation, a shape path, or a shader
/// uniform — which is what makes the rendering technology replaceable.
public enum PoseChannel: Int, CaseIterable, Sendable, Codable {
    case jawOpen        // 0…1   mouth opening — driven live by microphone loudness
    case mouthSmile     // -1…1  frown … smile
    case tongueOut      // 0…1
    case gazeX          // -1…1
    case gazeY          // -1…1
    case blink          // 0…1   1 = eyes fully closed
    case browLift       // -1…1  furrowed … raised
    case browAngle      // -1…1  sad … angry
    case headTilt       // radians
    case headTurn       // -1…1
    case headNod        // -1…1  pitch: chin down … chin up
    case bodyLean       // radians
    case bodyOffsetX    // points
    case bodyOffsetY    // points
    case bodyRotation   // radians — whole-puppet roll, used by spin and topple
    case squash         // 1 = neutral, <1 squashed, >1 stretched
    case breath         // 0…1 idle chest rise
    case armLeft        // radians, 0 = hanging
    case armRight       // radians
    case hairLag        // -1…1 secondary motion offset
    case shadowScale    // 1 = grounded, shrinks as the puppet leaves the floor
}

/// A complete description of the puppet for a single frame.
///
/// A plain value type on purpose: it is trivially testable, trivially diffable, and
/// can be handed to any number of renderers (or across a network to a second device)
/// without anything being shared or mutated behind your back.
public struct PuppetPose: Equatable, Sendable {

    private var storage: [Double]

    public init() {
        storage = Array(repeating: 0, count: PoseChannel.allCases.count)
        self[.squash] = 1
        self[.shadowScale] = 1
    }

    /// The puppet at rest: upright, centred, eyes open, mouth closed.
    public static let neutral = PuppetPose()

    public subscript(channel: PoseChannel) -> Double {
        get { storage[channel.rawValue] }
        set { storage[channel.rawValue] = newValue }
    }

    // MARK: Blending primitives
    //
    // Layers compose by calling these in order. `override` pulls a channel toward a
    // target (used by expressions and keyframed actions); `add` displaces it (used by
    // idle motion and live drivers). Ordering is the whole semantic: later layers win
    // proportionally to their weight, and nothing is ever mutually exclusive.

    /// Move a channel `weight` of the way toward `target`.
    public mutating func override(_ channel: PoseChannel, _ target: Double, weight: Double = 1) {
        let w = weight.clamped(to: 0...1)
        self[channel] += (target - self[channel]) * w
    }

    /// Displace a channel by `delta`, scaled by `weight`.
    public mutating func add(_ channel: PoseChannel, _ delta: Double, weight: Double = 1) {
        self[channel] += delta * weight
    }

    /// Clamp channels whose range is physically meaningful. Called once at the end of
    /// composition so intermediate layers can freely overshoot.
    public mutating func clampToLimits() {
        self[.jawOpen]     = self[.jawOpen].clamped(to: 0...1)
        self[.blink]       = self[.blink].clamped(to: 0...1)
        self[.tongueOut]   = self[.tongueOut].clamped(to: 0...1)
        self[.mouthSmile]  = self[.mouthSmile].clamped(to: -1...1)
        self[.gazeX]       = self[.gazeX].clamped(to: -1...1)
        self[.gazeY]       = self[.gazeY].clamped(to: -1...1)
        self[.browLift]    = self[.browLift].clamped(to: -1...1)
        self[.browAngle]   = self[.browAngle].clamped(to: -1...1)
        self[.headTurn]    = self[.headTurn].clamped(to: -1...1)
        self[.headNod]     = self[.headNod].clamped(to: -1...1)
        self[.squash]      = self[.squash].clamped(to: 0.5...1.6)
        self[.shadowScale] = self[.shadowScale].clamped(to: 0...1.2)
        self[.hairLag]     = self[.hairLag].clamped(to: -1.5...1.5)
    }

    /// Linear interpolation between two whole poses. Used for transitions and tests.
    public static func lerp(_ a: PuppetPose, _ b: PuppetPose, _ t: Double) -> PuppetPose {
        var out = a
        let t = t.clamped(to: 0...1)
        for channel in PoseChannel.allCases {
            out[channel] = a[channel] + (b[channel] - a[channel]) * t
        }
        return out
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
