import Foundation
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

@Suite("Cast")
struct CharacterLibraryTests {

    @Test("Every character is well formed and distinct")
    func castIsSane() {
        let all = CharacterLibrary.all
        #expect(all.count >= 4)
        #expect(Set(all.map(\.id)).count == all.count, "duplicate character id")
        #expect(Set(all.map(\.name)).count == all.count, "duplicate character name")

        for character in all {
            #expect(!character.name.isEmpty)
            #expect(!character.tagline.isEmpty)
            #expect(character.body.height > 0)
            #expect(character.head.halfWidth > 0 && character.head.halfHeight > 0)
            // The head must sit above the body's shoulders or it detaches visibly.
            #expect(character.head.centerY > character.body.height * 0.5,
                    "\(character.name): head is too low to meet the body")
            #expect(character.mouth.depth > 0)
            #expect(character.personality.breathPeriod > 0)
            #expect(character.personality.blinkInterval.lower > 0)
            #expect(character.personality.blinkInterval.upper >= character.personality.blinkInterval.lower)
            // The arms hang from the body, not from thin air.
            #expect(character.arms.shoulder.y <= character.body.height,
                    "\(character.name): shoulder is above the body")
        }
    }

    @Test("Characters actually differ in timing, not only in shape")
    func personalitiesDiffer() {
        let periods = Set(CharacterLibrary.all.map { $0.personality.breathPeriod })
        #expect(periods.count == CharacterLibrary.all.count,
                "if two characters breathe identically, one of them is redundant")
    }

    @Test("Descriptors survive a round trip, ready for character packs")
    func descriptorsAreCodable() throws {
        for character in CharacterLibrary.all {
            let data = try JSONEncoder().encode(character)
            let decoded = try JSONDecoder().decode(CharacterDescriptor.self, from: data)
            #expect(decoded == character, "\(character.name) did not survive encoding")
        }
    }

    @Test("Backdrops are well formed and round trip")
    func backdropsAreSane() throws {
        #expect(Set(BackdropLibrary.all.map(\.id)).count == BackdropLibrary.all.count)
        for backdrop in BackdropLibrary.all {
            #expect(!backdrop.name.isEmpty)
            #expect(!backdrop.symbol.isEmpty)
            let data = try JSONEncoder().encode(backdrop)
            #expect(try JSONDecoder().decode(Backdrop.self, from: data) == backdrop)
        }
        #expect(BackdropLibrary.backdrop(id: "nope").id == BackdropLibrary.default.id)
    }

    @Test("Character personality reaches the idle layer")
    func personalityDrivesIdle() {
        func breathRange(_ character: CharacterDescriptor) -> Double {
            var blender = PoseBlender()
            blender.idle.adopt(character.personality)
            var low = Double.infinity, high = -Double.infinity
            for _ in 0..<600 {
                let value = blender.tick(delta: 1.0 / 60).pose[.breath]
                low = min(low, value); high = max(high, value)
            }
            return high - low
        }
        // Both should breathe; the point is that the layer is actually consulted.
        #expect(breathRange(CharacterLibrary.pip) > 0.5)
        #expect(breathRange(CharacterLibrary.bramble) > 0.5)
    }
}
