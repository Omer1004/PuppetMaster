import Foundation

/// Runs whatever actions are currently in flight.
///
/// Several can overlap — waving while laughing is a better puppet than a queue that
/// makes you wait. Re-firing an action that is already running restarts it, which is
/// what a user tapping a button repeatedly expects.
public struct ActionScheduler: Sendable {

    private struct Running {
        let track: ActionTrack
        var time: Double
        var firedCues: Set<Int> = []
        var firedSounds: Set<Int> = []
    }

    /// One sound, ready to play. Pitch is relative; the character's own voice is
    /// applied on top by the engine.
    public struct SoundHit: Sendable, Equatable {
        public let sound: SoundID
        public let pitch: Double
    }

    /// Everything an action wants to happen at this instant that is not a pose.
    public struct Cues: Sendable {
        public var effects: [PuppetEffect] = []
        public var sounds: [SoundHit] = []
        public var isEmpty: Bool { effects.isEmpty && sounds.isEmpty }
    }

    private var running: [Running] = []

    public init() {}

    public var activeActions: Set<PuppetAction> { Set(running.map(\.track.id)) }

    /// True while an uninterruptible action owns the stage (currently only `topple`,
    /// where cutting the fall short destroys the joke).
    public var isLocked: Bool { running.contains { !$0.track.interruptible } }

    public mutating func fire(_ action: PuppetAction) {
        guard !isLocked else { return }
        let track = ActionLibrary.track(for: action)
        if let index = running.firstIndex(where: { $0.track.id == action }) {
            running[index] = Running(track: track, time: 0)   // restart
        } else {
            running.append(Running(track: track, time: 0))
        }
    }

    public mutating func cancelAll() { running.removeAll() }

    /// Advance time and return every cue whose moment was crossed this frame.
    public mutating func update(delta: Double) -> Cues {
        var cues = Cues()
        for i in running.indices {
            running[i].time += delta
            for (index, cue) in running[i].track.cues.enumerated()
            where running[i].time >= cue.time && !running[i].firedCues.contains(index) {
                running[i].firedCues.insert(index)
                cues.effects.append(cue.effect)
            }
            for (index, cue) in running[i].track.sounds.enumerated()
            where running[i].time >= cue.time && !running[i].firedSounds.contains(index) {
                running[i].firedSounds.insert(index)
                cues.sounds.append(SoundHit(sound: cue.sound, pitch: cue.pitch))
            }
        }
        running.removeAll { $0.time >= $0.track.duration }
        return cues
    }

    public func apply(to pose: inout PuppetPose) {
        for item in running {
            // Fade the last 12% of every action so a track never snaps back to rest.
            let remaining = item.track.duration - item.time
            let weight = remaining < item.track.duration * 0.12
                ? Easing.easeInOut.apply(remaining / (item.track.duration * 0.12))
                : 1

            for (channel, value) in item.track.sample(at: item.time) {
                if item.track.additive.contains(channel) {
                    pose.add(channel, value, weight: weight)
                } else {
                    pose.override(channel, value, weight: weight)
                }
            }
        }
    }
}
