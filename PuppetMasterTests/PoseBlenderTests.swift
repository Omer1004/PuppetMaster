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
            let pose = run(&blender, seconds: duration + 0.5)

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
