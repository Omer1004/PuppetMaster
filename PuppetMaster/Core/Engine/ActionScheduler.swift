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

    /// Advance time and return any effects whose cue time was crossed this frame.
    public mutating func update(delta: Double) -> [PuppetEffect] {
        var effects: [PuppetEffect] = []
        for i in running.indices {
            running[i].time += delta
            for (cueIndex, cue) in running[i].track.cues.enumerated()
            where running[i].time >= cue.time && !running[i].firedCues.contains(cueIndex) {
                running[i].firedCues.insert(cueIndex)
                effects.append(cue.effect)
            }
        }
        running.removeAll { $0.time >= $0.track.duration }
        return effects
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
