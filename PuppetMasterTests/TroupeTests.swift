import Testing
@testable import PuppetMaster

/// Two puppets on one stage. The rule these tests protect is that a second puppet is a
/// second *performance* — its own engine, its own pose, its own idle clock — and not one
/// puppet drawn twice.
@MainActor
@Suite("Troupe")
struct TroupeTests {

    @Test("A duet is two puppets, and going back is one")
    func castSize() {
        let troupe = Troupe()
        #expect(troupe.engines.count == 1)
        #expect(!troupe.isDuet)

        troupe.setDuet(true)
        #expect(troupe.engines.count == 2)
        #expect(troupe.isDuet)

        troupe.setDuet(false)
        #expect(troupe.engines.count == 1)
    }

    /// Turning on a duet and seeing the same character twice reads as a bug, so the
    /// second slot is filled with someone who is not already on stage.
    @Test("The second puppet is a different character")
    func partnerIsDistinct() {
        let troupe = Troupe()
        troupe.setDuet(true)
        #expect(troupe.engines[0].character.id != troupe.engines[1].character.id)
    }

    @Test("Focus decides who receives an intent")
    func focusRoutesIntents() {
        let troupe = Troupe()
        troupe.setDuet(true)

        troupe.send(.setExpression(.surprised))
        #expect(troupe.engines[0].expression == .surprised)
        #expect(troupe.engines[1].expression == .neutral)

        troupe.toggleFocus()
        troupe.send(.setExpression(.happy))
        #expect(troupe.engines[0].expression == .surprised)
        #expect(troupe.engines[1].expression == .happy)
    }

    /// Handing over while the old puppet is mid-gesture used to leave it frozen with its
    /// eyes locked wherever your thumb last was.
    @Test("Handing over releases what the old puppet was holding")
    func focusReleasesAim() {
        let troupe = Troupe()
        troupe.setDuet(true)
        troupe.send(.aim(x: 0.8, y: 0.4))
        #expect(troupe.engines[0].isAiming)

        troupe.toggleFocus()
        #expect(!troupe.engines[0].isAiming)
    }

    @Test("Staging is shared, characters are not")
    func stagingIsShared() {
        let troupe = Troupe()
        troupe.setDuet(true)
        let midnight = BackdropLibrary.all.first { $0.hasStars } ?? BackdropLibrary.default

        troupe.setBackdrop(midnight)
        #expect(troupe.engines.allSatisfy { $0.backdrop == midnight })
    }

    /// Two puppets whose boredom clocks start together yawn in unison, which reads as one
    /// mechanism rather than two characters with their own attention spans.
    @Test("The two puppets do not get bored in lockstep")
    func boredomIsStaggered() {
        let troupe = Troupe()
        troupe.setDuet(true)

        // Run past the first rung of the ladder and catch the frame where they differ.
        var sawDifference = false
        for _ in 0..<1200 {
            troupe.tick(delta: 1.0 / 60)
            if troupe.engines[0].activeActions != troupe.engines[1].activeActions {
                sawDifference = true
                break
            }
        }
        #expect(sawDifference)
    }

    @Test("Sound from either puppet reaches the one sound bank")
    func soundIsShared() {
        let troupe = Troupe()
        var heard: [SoundID] = []
        troupe.onSound = { id, _ in heard.append(id) }
        troupe.setDuet(true)

        troupe.send(.perform(.jump))
        for _ in 0..<180 { troupe.tick(delta: 1.0 / 60) }
        let afterFirst = heard.count
        #expect(afterFirst > 0)

        troupe.toggleFocus()
        troupe.send(.perform(.jump))
        for _ in 0..<180 { troupe.tick(delta: 1.0 / 60) }
        #expect(heard.count > afterFirst)
    }
}
