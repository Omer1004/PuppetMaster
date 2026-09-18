import Testing
@testable import PuppetMaster

/// The payoff of keeping `Core/` free of framework imports: the entire feel of the
/// puppet is exercised here in milliseconds, with no simulator, no screen, and no
/// microphone.
@Suite("Pose composition")
struct PoseBlenderTests {

    /// Advance a blender by `seconds` at a fixed step, as the display link would.
    private func run(_ blender: inout PoseBlender,
                     seconds: Double,
                     step: Double = 1.0 / 60) -> PuppetPose {
        var pose = PuppetPose.neutral
        var elapsed = 0.0
        while elapsed < seconds {
            pose = blender.tick(delta: step).pose
            elapsed += step
        }
        return pose
    }

    @Test("A resting puppet is never actually still")
    func idleKeepsTheCharacterAlive() {
        var blender = PoseBlender()
        var offsets: Set<Int> = []
        for _ in 0..<240 {
            let pose = blender.tick(delta: 1.0 / 60).pose
            offsets.insert(Int(pose[.bodyOffsetY] * 100))
        }
        // If this ever collapses to a single value the puppet has died on stage.
        #expect(offsets.count > 5)
    }

    @Test("Idle survives underneath every expression, not just Neutral")
    func idleSurvivesEveryExpression() {
        for expression in Expression.allCases {
            var blender = PoseBlender()
            blender.expression.setImmediately(expression)
            var offsets: Set<Int> = []
            for _ in 0..<240 {
                offsets.insert(Int(blender.tick(delta: 1.0 / 60).pose[.bodyOffsetY] * 100))
            }
            // The original bug: expressions overrode the union of ALL expressions'
            // channels, so any expression flattened breathing to a constant.
            #expect(offsets.count > 5, "\(expression) flattened the idle breathing")
        }
    }

    @Test("Double blinks actually happen")
    func doubleBlinksFire() {
        var personality = CharacterDescriptor.Personality()
        personality.doubleBlinkChance = 1.0        // every blink should be doubled
        var idle = IdleDriver()
        idle.adopt(personality)

        var time = 0.0, lastBlinkAt = -1.0
        var gaps: [Double] = []
        var wasClosed = false
        for _ in 0..<3600 {                        // 60s at 60fps
            idle.update(delta: 1.0 / 60)
            var pose = PuppetPose.neutral
            idle.apply(to: &pose)
            let closed = pose[.blink] > 0.5
            if closed && !wasClosed {
                if lastBlinkAt >= 0 { gaps.append(time - lastBlinkAt) }
                lastBlinkAt = time
            }
            wasClosed = closed
            time += 1.0 / 60
        }
        // A double blink is a second blink hard on the heels of the first. Before the
        // fix, the completion branch overwrote the short schedule and this was zero.
        #expect(gaps.contains { $0 < 0.5 },
                "no double blink in 60s at 100% chance; shortest gap was \(gaps.min() ?? -1)s")
    }

    @Test("Expression, action and speech all reach the pose at once")
    func layersCompose() {
        var blender = PoseBlender()
        blender.expression.setImmediately(.happy)
        blender.actions.fire(.wave)
        blender.live.jawDrive = 1.0

        let pose = run(&blender, seconds: 0.5)

        #expect(pose[.mouthSmile] > 0.3, "expression should still be showing")
        #expect(pose[.armRight] > 1.0, "wave should have the arm up")
        #expect(pose[.jawOpen] > 0.5, "speech should still open the mouth")
    }

    @Test("Speech is additive, so an action cannot mute the microphone")
    func laughDoesNotStealTheJaw() {
        var blender = PoseBlender()
        blender.live.jawDrive = 1.0
        _ = run(&blender, seconds: 0.4)
        let speaking = blender.tick(delta: 1.0 / 60).pose[.jawOpen]

        var withLaugh = PoseBlender()
        withLaugh.live.jawDrive = 1.0
        withLaugh.actions.fire(.laugh)
        _ = run(&withLaugh, seconds: 0.4)
        let both = withLaugh.tick(delta: 1.0 / 60).pose[.jawOpen]

        #expect(speaking > 0.5)
        #expect(both >= speaking - 0.05, "laughing must not close a talking mouth")
    }

    @Test("Every action returns the puppet to rest")
    func actionsSettle() {
        for action in PuppetAction.allCases {
            var blender = PoseBlender()
            blender.idle.intensity = 0            // isolate the action from idle sway
            blender.actions.fire(action)
            let duration = ActionLibrary.track(for: action).duration

            // Sample on the track's final frame, while it is still applied. Sampling
            // after it ends only proves the scheduler removes finished tracks — the pose
            // is trivially neutral by then, so any keyframes at all would pass.
            let atEnd = run(&blender, seconds: duration - 0.02)
            #expect(abs(atEnd[.bodyOffsetY]) < 14,
                    "\(action) is still \(atEnd[.bodyOffsetY])pt off the floor at its last frame")
            #expect(abs(atEnd[.armLeft]) < 0.45 && abs(atEnd[.armRight]) < 0.45,
                    "\(action) still has an arm raised at its last frame")

            let pose = run(&blender, seconds: 0.6)

            #expect(blender.actions.activeActions.isEmpty, "\(action) never finished")
            #expect(abs(pose[.bodyRotation]).truncatingRemainder(dividingBy: 2 * .pi) < 0.05,
                    "\(action) left the puppet rotated")
            #expect(abs(pose[.bodyOffsetY]) < 1.0, "\(action) left the puppet off the floor")
            #expect(abs(pose[.armLeft]) < 0.05 && abs(pose[.armRight]) < 0.05,
                    "\(action) left an arm raised")
        }
    }

    @Test("Poses stay inside their declared ranges under every layer at once")
    func posesStayInRange() {
        var blender = PoseBlender()
        blender.expression.setImmediately(.surprised)
        blender.live.jawDrive = 1.0
        blender.live.aim = SIMD2(5, -5)          // deliberately out of range
        for action in PuppetAction.allCases { blender.actions.fire(action) }

        for _ in 0..<180 {
            let pose = blender.tick(delta: 1.0 / 60).pose
            #expect((0...1).contains(pose[.jawOpen]))
            #expect((0...1).contains(pose[.blink]))
            #expect((-1...1).contains(pose[.gazeX]))
            #expect((-1...1).contains(pose[.gazeY]))
            #expect((0.5...1.6).contains(pose[.squash]))
        }
    }

    @Test("A stalled frame cannot teleport the puppet")
    func longFrameIsClamped() {
        var blender = PoseBlender()
        blender.actions.fire(.jump)
        _ = blender.tick(delta: 5.0)             // e.g. returning from the background
        #expect(!blender.actions.activeActions.isEmpty,
                "a single huge delta should not fast-forward the whole performance")
    }

    @Test("Topple refuses to be cut short")
    func uninterruptibleActionHolds() {
        var blender = PoseBlender()
        blender.actions.fire(.topple)
        _ = run(&blender, seconds: 0.3)
        blender.actions.fire(.jump)
        #expect(blender.actions.activeActions == [.topple])
    }
}
