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
            for cue in track.sounds {
                #expect(cue.time <= track.duration, "\(action) has a sound after it ends")
                #expect(cue.pitch > 0, "\(action) has a non-positive sound pitch")
            }
        }
    }

    @Test("Effect cues fire exactly once")
    func cuesFireOnce() {
        var scheduler = ActionScheduler()
        scheduler.fire(.jump)
        var impacts = 0
        for _ in 0..<120 {
            impacts += scheduler.update(delta: 1.0 / 60).effects.count { $0 == .impact }
        }
        #expect(impacts == 1)
    }

    @Test("Sound cues fire exactly once, and every action makes a noise")
    func soundCuesFireOnce() {
        for action in PuppetAction.allCases {
            let track = ActionLibrary.track(for: action)
            #expect(!track.sounds.isEmpty, "\(action) is silent")

            var scheduler = ActionScheduler()
            scheduler.fire(action)
            var heard: [SoundID] = []
            let frames = Int((track.duration + 0.5) * 60)
            for _ in 0..<frames {
                heard.append(contentsOf: scheduler.update(delta: 1.0 / 60).sounds.map(\.sound))
            }
            #expect(heard.count == track.sounds.count,
                    "\(action) fired \(heard.count) sounds, expected \(track.sounds.count)")
        }
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

    @Test("Character personality actually changes the idle timing")
    func personalityDrivesIdle() {
        /// Count breaths in 30s. This distinguishes characters, where a range check
        /// would pass identically if `adopt()` did nothing at all.
        func breaths(_ character: CharacterDescriptor) -> Int {
            var blender = PoseBlender()
            blender.idle.adopt(character.personality)
            var crossings = 0
            var wasRising = false
            for _ in 0..<1800 {
                let value = blender.tick(delta: 1.0 / 60).pose[.breath]
                let rising = value > 0.5
                if rising && !wasRising { crossings += 1 }
                wasRising = rising
            }
            return crossings
        }

        let pip = breaths(CharacterLibrary.pip)          // 2.1s period
        let bramble = breaths(CharacterLibrary.bramble)  // 5.6s period
        #expect(pip > bramble * 2,
                "Pip (\(pip) breaths) should breathe far faster than Bramble (\(bramble))")
    }

    @Test("Every character has its own voice")
    func voicesDiffer() {
        let pitches = Set(CharacterLibrary.all.map { $0.personality.voicePitch })
        #expect(pitches.count == CharacterLibrary.all.count)
        for character in CharacterLibrary.all {
            #expect(character.personality.voicePitch > 0)
        }
    }

    @Test("A malformed track cannot NaN-poison the pose")
    func zeroDurationIsClamped() {
        let track = ActionTrack(id: .wave, duration: 0, channels: [.armRight: [Keyframe(0, 1)]])
        #expect(track.duration > 0)
    }
}
