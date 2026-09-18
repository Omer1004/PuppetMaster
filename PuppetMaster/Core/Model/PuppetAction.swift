import Foundation

/// A one-shot performance beat. Fires, plays, and gets out of the way — actions layer
/// on top of whatever expression is held and whatever the microphone is doing.
public enum PuppetAction: String, CaseIterable, Identifiable, Sendable, Codable {
    case wave, laugh, jump, spin, nod, shake, topple

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wave:   "Wave"
        case .laugh:  "Laugh"
        case .jump:   "Jump"
        case .spin:   "Spin"
        case .nod:    "Yes"
        case .shake:  "No"
        case .topple: "Topple"
        }
    }

    public var symbol: String {
        switch self {
        case .wave:   "hand.wave.fill"
        case .laugh:  "face.smiling.inverse"
        case .jump:   "arrow.up.circle.fill"
        case .spin:   "arrow.trianglehead.2.clockwise.rotate.90"
        case .nod:    "checkmark.circle.fill"
        case .shake:  "xmark.circle.fill"
        case .topple: "tornado"
        }
    }
}

/// One point on one channel's curve.
public struct Keyframe: Sendable, Codable {
    public let time: Double        // seconds from the start of the action
    public let value: Double
    public let easing: Easing      // curve used to reach this keyframe from the previous one

    public init(_ time: Double, _ value: Double, _ easing: Easing = .easeInOut) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

/// A transient effect fired at a point in an action's timeline.
public struct EffectCue: Sendable {
    public let time: Double
    public let effect: PuppetEffect
    public init(_ time: Double, _ effect: PuppetEffect) {
        self.time = time
        self.effect = effect
    }
}

/// A short, authored performance: curves over pose channels, plus optional cues.
///
/// Deliberately data, not code. These are defined in `ActionLibrary` today and are
/// intended to move to per-character JSON so that a new character is an art task
/// rather than an engineering one.
public struct ActionTrack: Sendable {
    public let id: PuppetAction
    public let duration: Double
    public let channels: [PoseChannel: [Keyframe]]
    /// Channels that displace the pose instead of taking it over. Use for anything a
    /// live driver also writes — above all `jawOpen`, which the microphone owns.
    public let additive: Set<PoseChannel>
    public let cues: [EffectCue]
    public let interruptible: Bool

    public init(id: PuppetAction,
                duration: Double,
                additive: Set<PoseChannel> = [],
                interruptible: Bool = true,
                cues: [EffectCue] = [],
                channels: [PoseChannel: [Keyframe]]) {
        self.id = id
        self.duration = duration
        self.additive = additive
        self.interruptible = interruptible
        self.cues = cues
        self.channels = channels
    }

    /// Sample every channel at `time`, returning only channels this track drives.
    public func sample(at time: Double) -> [PoseChannel: Double] {
        var out: [PoseChannel: Double] = [:]
        out.reserveCapacity(channels.count)
        for (channel, frames) in channels {
            if let value = Self.sample(frames, at: time) { out[channel] = value }
        }
        return out
    }

    static func sample(_ frames: [Keyframe], at time: Double) -> Double? {
        guard let first = frames.first else { return nil }
        if time <= first.time { return first.value }
        guard let last = frames.last else { return nil }
        if time >= last.time { return last.value }

        for i in 1..<frames.count {
            let a = frames[i - 1], b = frames[i]
            if time <= b.time {
                let span = b.time - a.time
                guard span > 0 else { return b.value }
                let t = b.easing.apply((time - a.time) / span)
                return a.value + (b.value - a.value) * t
            }
        }
        return last.value
    }
}
