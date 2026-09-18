import Testing
@testable import PuppetMaster

@Suite("StageLayout")
struct StageLayoutTests {

    @Test("A phone in portrait stacks the stage above the controls")
    func portraitStacks() {
        // iPhone 18 Pro, points.
        let layout = StageLayout.forSurface(width: 402, height: 874)
        #expect(layout == .stacked(fraction: StageLayout.stackedFraction))
        #expect(!layout.isSideBySide)
    }

    @Test("A phone in landscape puts the stage beside the controls")
    func landscapeSplitsSideways() {
        let layout = StageLayout.forSurface(width: 874, height: 402)
        #expect(layout == .sideBySide(fraction: StageLayout.sideBySideFraction))
        #expect(layout.isSideBySide)
    }

    @Test("An iPad in portrait stacks, because it is taller than it is wide")
    func iPadPortraitStacks() {
        #expect(!StageLayout.forSurface(width: 834, height: 1194).isSideBySide)
    }

    @Test("An iPad in landscape splits sideways")
    func iPadLandscapeSplits() {
        #expect(StageLayout.forSurface(width: 1194, height: 834).isSideBySide)
    }

    /// The case this threshold exists for. A folding device's inner screen is close to
    /// square; splitting it into two columns would leave the puppet unreadably small.
    @Test("A near-square surface stays stacked")
    func nearSquareStaysStacked() {
        #expect(!StageLayout.forSurface(width: 1000, height: 900).isSideBySide)
        #expect(!StageLayout.forSurface(width: 1100, height: 1000).isSideBySide)
    }

    @Test("The threshold is inclusive at exactly 1.2")
    func thresholdIsInclusive() {
        #expect(StageLayout.forSurface(width: 1200, height: 1000).isSideBySide)
        #expect(!StageLayout.forSurface(width: 1199, height: 1000).isSideBySide)
    }

    /// `GeometryReader` reports zero on the first pass often enough that this is a real
    /// case, not a defensive one. Stacked is the safe answer: it is what portrait wants,
    /// and a phone is in portrait when it launches.
    @Test("A degenerate size falls back to stacked")
    func degenerateSizeFallsBack() {
        #expect(!StageLayout.forSurface(width: 0, height: 0).isSideBySide)
        #expect(!StageLayout.forSurface(width: -5, height: 100).isSideBySide)
        #expect(StageLayout.forSurface(width: 0, height: 0).fraction == StageLayout.stackedFraction)
    }

    @Test("Both fractions leave a usable share for each half")
    func fractionsAreSane() {
        for layout in [StageLayout.forSurface(width: 402, height: 874),
                       StageLayout.forSurface(width: 874, height: 402)] {
            #expect(layout.fraction > 0.3)
            #expect(layout.fraction < 0.7)
        }
    }
}
