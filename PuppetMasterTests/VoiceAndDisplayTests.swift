import Testing
@testable import PuppetMaster

@Suite("Smoothing")
struct SmootherTests {

    @Test("Rises quickly and falls slowly, so a mouth does not flicker")
    func attackIsFasterThanRelease() {
        var rising = Smoother(value: 0, attack: 0.02, release: 0.2)
        var falling = Smoother(value: 1, attack: 0.02, release: 0.2)

        for _ in 0..<3 {
            rising.update(target: 1, delta: 1.0 / 60)
            falling.update(target: 0, delta: 1.0 / 60)
        }
        #expect(rising.value > 0.8)
        #expect(falling.value > 0.6, "release should still be on its way down")
    }

    @Test("Frame rate does not change where the signal lands")
    func isFrameRateIndependent() {
        var slow = Smoother(value: 0, attack: 0.1, release: 0.1)
        var fast = Smoother(value: 0, attack: 0.1, release: 0.1)

        for _ in 0..<30 { slow.update(target: 1, delta: 1.0 / 30) }
        for _ in 0..<120 { fast.update(target: 1, delta: 1.0 / 120) }

        #expect(abs(slow.value - fast.value) < 0.01)
    }
}

@Suite("Silly voice")
struct SillyVoiceTests {

    @Test("Babbles: opens and closes rather than sitting at one level")
    func producesVaryingLevels() {
        var driver = SillyVoiceDriver()
        var sawOpen = false
        var sawClosed = false
        for _ in 0..<600 {
            let level = driver.update(delta: 1.0 / 60)
            #expect((0...1).contains(level))
            if level > 0.4 { sawOpen = true }
            if level < 0.05 { sawClosed = true }
        }
        #expect(sawOpen && sawClosed)
    }
}

@Suite("Display routing")
@MainActor
struct DisplayRoutingTests {

    @Test("Duo is offered but honestly reported as unavailable")
    func duoIsUnavailableAndSaysWhy() {
        let router = StageRouter()
        #expect(router.allModes.contains(.duo), "Duo should still be listed")
        #expect(!router.isAvailable(.duo))
        #expect(router.unavailableReason(for: .duo) != nil)
    }

    @Test("A mode that is not available cannot be selected")
    func cannotSelectUnavailableMode() {
        let router = StageRouter()
        router.select(.duo)
        #expect(router.mode == .solo)
        router.select(.duoRehearsal)
        #expect(router.mode == .duoRehearsal)
    }

    @Test("Connecting a display moves the stage to it, and removing it brings it back")
    func externalDisplayLifecycle() {
        let router = StageRouter()
        #expect(!router.isAvailable(.externalDisplay))

        router.externalSurfaceConnected()
        #expect(router.isExternalDisplayConnected)
        #expect(router.mode == .externalDisplay)
        #expect(router.roleForPrimarySurface == .controls, "the phone keeps only the controls")

        router.externalSurfaceDisconnected()
        #expect(!router.isExternalDisplayConnected)
        #expect(router.mode == .solo)
    }

    @Test("Every mode that splits the experience asks for both roles")
    func splitModesRequestBothRoles() {
        for mode in [PresentationMode.duoRehearsal, .externalDisplay, .duo] {
            #expect(mode.roles == [.stage, .controls], "\(mode) should separate the two roles")
        }
        #expect(PresentationMode.solo.roles == [.combined])
    }
}

@Suite("Engine")
@MainActor
struct PuppetEngineTests {

    final class RecordingRenderer: PuppetRenderer {
        var poses: [PuppetPose] = []
        var effects: [PuppetEffect] = []
        var loaded: [String] = []
        func load(character: CharacterDescriptor) { loaded.append(character.id) }
        func apply(pose: PuppetPose) { poses.append(pose) }
        func fire(effect: PuppetEffect) { effects.append(effect) }
    }

    @Test("One engine drives every attached surface with the same frame")
    func allSurfacesReceiveTheSamePose() {
        let engine = PuppetEngine()
        let phone = RecordingRenderer()
        let externalDisplay = RecordingRenderer()
        engine.addRenderer(phone)
        engine.addRenderer(externalDisplay)
        #expect(engine.rendererCount == 2)

        for _ in 0..<10 { engine.tick(delta: 1.0 / 60) }

        #expect(phone.poses.count == externalDisplay.poses.count)
        #expect(phone.poses.last == externalDisplay.poses.last,
                "two surfaces must never show different frames")
    }

    @Test("Adding the same surface twice does not double up")
    func renderersAreUnique() {
        let engine = PuppetEngine()
        let renderer = RecordingRenderer()
        engine.addRenderer(renderer)
        engine.addRenderer(renderer)
        #expect(engine.rendererCount == 1)
    }

    @Test("Detaching a surface stops it being drawn")
    func removingARendererStopsDelivery() {
        let engine = PuppetEngine()
        let renderer = RecordingRenderer()
        engine.addRenderer(renderer)
        engine.tick(delta: 1.0 / 60)
        let afterFirstFrame = renderer.poses.count

        engine.removeRenderer(renderer)
        engine.tick(delta: 1.0 / 60)
        #expect(renderer.poses.count == afterFirstFrame)
        #expect(engine.rendererCount == 0)
    }

    @Test("Switching character reloads every attached surface")
    func castChangeReachesAllSurfaces() {
        let engine = PuppetEngine()
        let phone = RecordingRenderer()
        let display = RecordingRenderer()
        engine.addRenderer(phone)
        engine.addRenderer(display)
        #expect(phone.loaded == [CharacterLibrary.default.id])

        engine.send(.setCharacter(id: CharacterLibrary.bramble.id))
        #expect(engine.character.id == "bramble")
        #expect(phone.loaded.last == "bramble")
        #expect(display.loaded.last == "bramble", "a second surface must not keep the old cast")
    }

    @Test("Switching character cancels whatever the previous one was doing")
    func castChangeCancelsActions() {
        let engine = PuppetEngine()
        engine.send(.perform(.topple))
        #expect(!engine.activeActions.isEmpty)
        engine.send(.setCharacter(id: CharacterLibrary.pip.id))
        engine.tick(delta: 1.0 / 60)
        #expect(engine.activeActions.isEmpty, "an in-flight action belongs to the old character")
    }

    @Test("An unknown character id falls back rather than failing")
    func unknownCharacterFallsBack() {
        #expect(CharacterLibrary.character(id: "nobody").id == CharacterLibrary.default.id)
    }

    @Test("Intents are the only way state changes")
    func intentsDriveState() {
        let engine = PuppetEngine()
        engine.send(.setExpression(.silly))
        #expect(engine.expression == .silly)

        engine.send(.perform(.jump))
        #expect(engine.activeActions.contains(.jump))

        engine.send(.aim(x: 0.5, y: -0.5))
        #expect(engine.isAiming)
        engine.send(.releaseAim)
        #expect(!engine.isAiming)
    }
}
