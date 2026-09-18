import SpriteKit

/// One rendering surface: the stage itself.
///
/// The scene owns what a *stage* has — sky, floor, stars — and one ``StagePerformer``
/// per puppet standing on it. It is not itself a ``PuppetRenderer``; performers are.
/// That split is what lets two puppets share one sky instead of sitting in two boxes
/// with a seam down the middle.
///
/// Several scenes can exist at once — the phone's stage and an external display, or the
/// two halves of a folding device — all driven by the same engines and one clock, which
/// is what keeps them frame-accurately in step.
///
/// The scene runs no animation of its own: it has no `update(_:)` logic and owns no
/// timeline. It is a pure function of the poses it is handed.
@MainActor
final class PuppetScene: SKScene {

    private(set) var performers: [StagePerformer] = []
    private let world = SKNode()
    private var backdropNode: SKSpriteNode?
    private var floorNode: SKShapeNode?
    private var starField: SKNode?

    private var backdrop: Backdrop = BackdropLibrary.default
    /// Which puppet the performer's thumbs are currently driving, or nil when there is
    /// only one and the question does not arise.
    private var focusIndex: Int?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = backdrop.skyBottom.uiColor
        setPerformerCount(1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("PuppetScene is created in code") }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false

        // Only node *creation* is one-time. Draining a pending character and relaying
        // out must happen on every attach, or a scene reattached to a second view keeps
        // the old size and silently drops a character loaded while it was detached.
        if backdropNode == nil { buildSceneFurniture() }

        for performer in performers { performer.becameLive() }
        applyBackdrop()
        layout()
    }

    private func buildSceneFurniture() {
        let backdropNode = SKSpriteNode(texture: nil, color: .clear, size: size)
        backdropNode.zPosition = -100
        addChild(backdropNode)
        self.backdropNode = backdropNode

        let floor = SKShapeNode()
        floor.strokeColor = .clear
        floor.zPosition = -90
        addChild(floor)
        self.floorNode = floor

        addChild(world)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        applyBackdrop()
        layout()
    }

    // MARK: Cast

    /// How many puppets stand on this stage. Adding one is all a duet needs from the
    /// rendering side — the second puppet's animation comes from its own engine.
    func setPerformerCount(_ count: Int) {
        let count = max(1, count)
        guard count != performers.count else { return }

        while performers.count > count {
            performers.removeLast().world.removeFromParent()
        }
        while performers.count < count {
            let performer = StagePerformer()
            performer.isLive = view != nil
            performer.backdrop = backdrop
            performer.onNeedsLayout = { [weak self] in self?.layout() }
            world.addChild(performer.world)
            performers.append(performer)
        }
        layout()
    }

    /// The renderer for one puppet. The caller registers it with that puppet's engine.
    func performer(at index: Int) -> StagePerformer? {
        performers.indices.contains(index) ? performers[index] : nil
    }

    func setFocus(_ index: Int?) {
        guard index != focusIndex else { return }
        focusIndex = index
        for (i, performer) in performers.enumerated() {
            performer.setFocused(isFocused(i), animated: true)
        }
    }

    /// With one puppet on stage there is nothing to choose between, so it is always
    /// fully lit — the dimming is only ever a duet's answer to "which one am I driving".
    private func isFocused(_ index: Int) -> Bool {
        guard performers.count > 1, let focusIndex else { return true }
        return index == focusIndex
    }

    /// Which puppet a touch at this point belongs to, so that poking the puppet on the
    /// left pokes the one on the left.
    func performerIndex(atX x: CGFloat) -> Int {
        guard performers.count > 1, size.width > 0 else { return 0 }
        let slot = Int(x / (size.width / CGFloat(performers.count)))
        return min(max(slot, 0), performers.count - 1)
    }

    // MARK: Staging

    func setBackdrop(_ backdrop: Backdrop) {
        guard backdrop != self.backdrop else { return }
        self.backdrop = backdrop
        backgroundColor = backdrop.skyBottom.uiColor
        for performer in performers { performer.setBackdrop(backdrop) }
        applyBackdrop()
        layout()
    }

    // MARK: Layout

    /// Fit the puppets to whatever surface they landed on. The same scene runs full-bleed
    /// on an external display and in a half-height panel on a phone, with characters of
    /// very different proportions, so the scale comes from each rig rather than a
    /// constant.
    private func layout() {
        guard size.width > 0, size.height > 0, !performers.isEmpty else { return }

        let floorY = size.height * 0.16
        let available = size.height - floorY - size.height * 0.05
        let slotWidth = size.width / CGFloat(performers.count)

        for (index, performer) in performers.enumerated() {
            // Two puppets are given a little more room than their slot and allowed to
            // overlap slightly. Strictly separated they read as two photographs side by
            // side; overlapping, they read as two characters sharing a stage.
            let width = performers.count > 1 ? slotWidth * 1.16 : slotWidth
            let scale = min(width / performer.designWidth, available / performer.designHeight)
            let x = slotWidth * (CGFloat(index) + 0.5)
            performer.place(at: CGPoint(x: x, y: floorY),
                            scale: max(scale, 0.05),
                            focused: isFocused(index))
        }

        backdropNode?.size = size
        backdropNode?.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // A soft floor band, so the puppets stand on something rather than floating.
        floorNode?.path = CGPath(ellipseIn: CGRect(x: -size.width * 0.25,
                                                   y: floorY - size.height * 0.55,
                                                   width: size.width * 1.5,
                                                   height: size.height * 0.55), transform: nil)
        layoutStars()
    }

    private func applyBackdrop() {
        backdropNode?.texture = ParticleTextures.gradient(
            size: CGSize(width: 16, height: max(size.height.rounded(), 16)),
            top: backdrop.skyTop.uiColor,
            bottom: backdrop.skyBottom.uiColor)
        floorNode?.fillColor = backdrop.floor.uiColor

        starField?.removeFromParent()
        starField = nil
        guard backdrop.hasStars else { return }

        let field = SKNode()
        field.zPosition = -95
        addChild(field)
        starField = field
        // `layout()` populates it; doing it here as well built 88 sprites where 44 do.
    }

    private func layoutStars() {
        guard let starField, backdrop.hasStars, size.width > 0 else { return }
        starField.removeAllChildren()

        // Deterministic placement: a seeded generator means stars do not reshuffle every
        // time the view resizes, which would read as flicker.
        var generator = SeededGenerator(seed: 0x5EED)
        for _ in 0..<44 {
            let star = SKSpriteNode(texture: ParticleTextures.soft(radius: 5, color: .white))
            star.position = CGPoint(x: .random(in: 0...size.width, using: &generator),
                                    y: .random(in: size.height * 0.22...size.height, using: &generator))
            star.alpha = .random(in: 0.25...0.85, using: &generator)
            star.setScale(.random(in: 0.5...1.3, using: &generator))
            let period = Double.random(in: 1.8...4.2, using: &generator)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: period),
                .fadeAlpha(to: Double(star.alpha), duration: period),
            ])))
            starField.addChild(star)
        }
    }
}

/// A tiny deterministic generator, so star placement is stable across relayouts.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
