import SpriteKit

/// One rendering surface for the puppet.
///
/// Conforms to ``PuppetRenderer``, so the engine treats it identically to any other
/// surface. Several can exist at once — the phone's stage and an external display, or
/// the two halves of a folding device — all driven by one engine and one clock, which
/// is what keeps them frame-accurately in step.
///
/// The scene runs no animation of its own: it has no `update(_:)` logic and owns no
/// timeline. It is a pure function of the pose it is handed.
@MainActor
final class PuppetScene: SKScene, PuppetRenderer {

    private var rig: PuppetRig?
    private var pendingCharacter: CharacterDescriptor?
    private let world = SKNode()
    private var backdropNode: SKSpriteNode?
    private var floorNode: SKShapeNode?
    private var starField: SKNode?
    private var latestPose: PuppetPose = .neutral

    private var backdrop: Backdrop = BackdropLibrary.default

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = backdrop.skyBottom.uiColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("PuppetScene is created in code") }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false

        guard backdropNode == nil else { return }

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

        // A character may have been handed to us before we had a view to build it in.
        if let pendingCharacter {
            self.pendingCharacter = nil
            build(character: pendingCharacter)
        }
        applyBackdrop()
        layout()
        rig?.apply(pose: latestPose)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        applyBackdrop()
        layout()
    }

    // MARK: Content

    func setBackdrop(_ backdrop: Backdrop) {
        guard backdrop != self.backdrop else { return }
        self.backdrop = backdrop
        backgroundColor = backdrop.skyBottom.uiColor
        applyBackdrop()
        layout()
    }

    private func build(character: CharacterDescriptor) {
        rig?.root.removeFromParent()
        let rig = PuppetRig(character: character)
        world.addChild(rig.root)
        self.rig = rig
        layout()
        rig.apply(pose: latestPose)
    }

    // MARK: Layout

    /// Fit the puppet to whatever surface it landed on. The same scene runs full-bleed on
    /// an external display and in a half-height panel on a phone, with characters of very
    /// different proportions, so the scale comes from the rig rather than a constant.
    private func layout() {
        guard size.width > 0, size.height > 0 else { return }

        let floorY = size.height * 0.16
        let available = size.height - floorY - size.height * 0.05
        let designWidth = rig?.designWidth ?? 300
        let designHeight = rig?.designHeight ?? 470
        let scale = min(size.width / designWidth, available / designHeight)

        world.setScale(max(scale, 0.05))
        world.position = CGPoint(x: size.width / 2, y: floorY)

        backdropNode?.size = size
        backdropNode?.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // A soft floor band, so the puppet stands on something rather than floating.
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
        layoutStars()
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

    // MARK: PuppetRenderer

    func load(character: CharacterDescriptor) {
        guard view != nil else {
            // Not on screen yet; build once `didMove(to:)` gives us a view.
            pendingCharacter = character
            return
        }
        build(character: character)
    }

    func apply(pose: PuppetPose) {
        latestPose = pose
        rig?.apply(pose: pose)
    }

    func fire(effect: PuppetEffect) {
        guard rig != nil else { return }
        // Do NOT set `position` here: each effect chooses its own spawn point in
        // `makeEmitters` (dust at the feet, sparkle at the head, confetti from above),
        // and the rig's root is always the world origin.
        for emitter in makeEmitters(for: effect) {
            emitter.targetNode = world
            world.addChild(emitter)
            // Emitters are one-shot: let them empty, then clean themselves up.
            emitter.run(.sequence([
                .wait(forDuration: 0.12),
                .run { emitter.particleBirthRate = 0 },
                .wait(forDuration: 3.0),
                .removeFromParent(),
            ]))
        }
    }

    /// Most effects are a single emitter. Confetti is several, because SpriteKit's
    /// `particleColorSequence` varies a colour over one particle's *lifetime* — it
    /// cannot give each scrap of paper its own colour. One emitter per colour can.
    private func makeEmitters(for effect: PuppetEffect) -> [SKEmitterNode] {
        guard effect == .confetti else {
            return [makeEmitter(for: effect)]
        }
        return [UIColor.systemPink, .systemYellow, .systemTeal, .systemOrange,
                UIColor.systemPurple].map { colour in
            let emitter = makeEmitter(for: .confetti)
            emitter.particleTexture = ParticleTextures.chip(size: 14, color: colour)
            emitter.particleBirthRate /= 5
            emitter.particleColorBlendFactor = 0
            return emitter
        }
    }

    private func makeEmitter(for effect: PuppetEffect) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.zPosition = 5
        let headY = rig?.headHeight ?? 250

        switch effect {
        case .dustPuff:
            emitter.particleTexture = ParticleTextures.soft(radius: 22, color: .white)
            emitter.particleBirthRate = 260
            emitter.particleLifetime = 0.55
            emitter.particleLifetimeRange = 0.25
            emitter.particlePositionRange = CGVector(dx: 150, dy: 10)
            emitter.particleSpeed = 90
            emitter.particleSpeedRange = 60
            emitter.emissionAngleRange = .pi
            emitter.yAcceleration = 40
            emitter.particleAlpha = 0.55
            emitter.particleAlphaSpeed = -1.2
            emitter.particleScale = 0.5
            emitter.particleScaleRange = 0.35
            emitter.particleScaleSpeed = 0.8
            emitter.particleColor = backdrop.floor.uiColor
            emitter.particleColorBlendFactor = 0.8

        case .sparkle:
            emitter.position = CGPoint(x: 0, y: headY)
            emitter.particleTexture = ParticleTextures.symbol("sparkle", size: 26, color: .white)
            emitter.particleBirthRate = 70
            emitter.particleLifetime = 0.9
            emitter.particlePositionRange = CGVector(dx: 230, dy: 190)
            emitter.particleSpeed = 34
            emitter.emissionAngleRange = .pi * 2
            emitter.particleAlpha = 0.95
            emitter.particleAlphaSpeed = -1.0
            emitter.particleScale = 0.75
            emitter.particleScaleRange = 0.4
            emitter.particleScaleSpeed = -0.35
            emitter.particleRotationRange = .pi

        case .confetti:
            emitter.position = CGPoint(x: 0, y: headY * 2.6)
            emitter.particleTexture = ParticleTextures.chip(size: 14, color: .white)
            emitter.particleBirthRate = 300
            emitter.particleLifetime = 2.6
            emitter.particlePositionRange = CGVector(dx: 300, dy: 20)
            emitter.particleSpeed = 60
            emitter.particleSpeedRange = 50
            emitter.emissionAngle = -.pi / 2
            emitter.emissionAngleRange = .pi / 3
            emitter.yAcceleration = -190
            emitter.particleAlpha = 1
            emitter.particleAlphaSpeed = -0.3
            emitter.particleScale = 0.7
            emitter.particleRotationRange = .pi * 2
            emitter.particleRotationSpeed = 4
            emitter.particleColorSequence = nil

        case .musicNotes:
            emitter.position = CGPoint(x: 0, y: headY * 0.92)
            emitter.particleTexture = ParticleTextures.symbol("music.note", size: 30, color: .white)
            emitter.particleBirthRate = 7
            emitter.particleLifetime = 2.2
            emitter.particlePositionRange = CGVector(dx: 210, dy: 30)
            emitter.particleSpeed = 46
            emitter.particleSpeedRange = 20
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = .pi / 5
            emitter.xAcceleration = 14
            emitter.particleAlpha = 0.9
            emitter.particleAlphaSpeed = -0.4
            emitter.particleScale = 0.85
            emitter.particleScaleRange = 0.3
            emitter.particleRotationRange = 0.7
            emitter.particleColor = .white
            emitter.particleColorBlendFactor = 1
        }
        return emitter
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
