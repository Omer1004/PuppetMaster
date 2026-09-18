import Testing
@testable import PuppetMaster

@Suite("Action tracks")
struct ActionTrackTests {

    @Test("Keyframes hold before the first and after the last")
    func samplingClampsAtTheEnds() {
        let frames = [Keyframe(0.0, 0.0), Keyframe(1.0, 10.0)]
        #expect(ActionTrack.sample(frames, at: -1) == 0)
        #expect(ActionTrack.sample(frames, at: 2) == 10)
    }

    @Test("Keyframes interpolate between points")
    func samplingInterpolates() {
        let frames = [Keyframe(0.0, 0.0, .linear), Keyframe(1.0, 10.0, .linear)]
        let midpoint = try! #require(ActionTrack.sample(frames, at: 0.5))
        #expect(abs(midpoint - 5.0) < 0.001)
    }

    @Test("Every built-in action is well formed")
    func libraryIsSane() {
        for action in PuppetAction.allCases {
            let track = ActionLibrary.track(for: action)
            #expect(track.id == action, "\(action) is registered under the wrong id")
            #expect(track.duration > 0)
            #expect(!track.channels.isEmpty)

            for (channel, frames) in track.channels {
                #expect(!frames.isEmpty, "\(action).\(channel) has no keyframes")
                let times = frames.map(\.time)
                #expect(times == times.sorted(), "\(action).\(channel) keyframes are out of order")
                #expect(times.last! <= track.duration + 0.001,
                        "\(action).\(channel) runs past the track duration")
            }
            for cue in track.cues {
                #expect(cue.time <= track.duration, "\(action) has a cue after it ends")
            }
        }
    }

    @Test("Effect cues fire exactly once")
    func cuesFireOnce() {
        var scheduler = ActionScheduler()
        scheduler.fire(.jump)
        var dustPuffs = 0
        for _ in 0..<120 {
            dustPuffs += scheduler.update(delta: 1.0 / 60).count(where: { $0 == .dustPuff })
        }
        #expect(dustPuffs == 1)
    }

    @Test("Re-firing an action restarts it rather than stacking it")
    func refiringRestarts() {
        var scheduler = ActionScheduler()
        scheduler.fire(.wave)
        _ = scheduler.update(delta: 0.5)
        scheduler.fire(.wave)
        #expect(scheduler.activeActions == [.wave])
        _ = scheduler.update(delta: ActionLibrary.track(for: .wave).duration - 0.4)
        #expect(scheduler.activeActions == [.wave], "the restart should not have expired yet")
    }
}
