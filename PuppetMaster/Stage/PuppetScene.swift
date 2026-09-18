import SpriteKit

/// One rendering surface for the puppet.
///
/// Conforms to ``PuppetRenderer``, so the engine treats it identically to any other
/// surface. Several of these can exist simultaneously — the phone's stage and an
/// external display, or the two halves of a folding device — all driven by one engine
/// and one clock, which is what keeps them frame-accurately in step.
///
/// The scene never runs its own animation: it has no `update(_:)` logic and owns no
/// timeline. It is a pure function of the pose it is handed.
@MainActor
final class PuppetScene: SKScene, PuppetRenderer {

    private var rig: MoppetRig?
    private let world = SKNode()
    private var backdrop: SKSpriteNode?
    private var floor: SKShapeNode?
    private var latestPose: PuppetPose = .neutral

    /// Design height of the puppet in rig units, used to fit it to any surface.
    private let designHeight: CGFloat = 470
    private let designWidth: CGFloat = 300

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = MoppetPalette.stageBottom
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("PuppetScene is created in code") }

    override func didMove(to view: SKView) {
        guard rig == nil else { return }

        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false

        let backdrop = SKSpriteNode(texture: nil, color: .clear, size: size)
        backdrop.zPosition = -100
        addChild(backdrop)
        self.backdrop = backdrop

        let floor = SKShapeNode()
        floor.fillColor = MoppetPalette.floor
        floor.strokeColor = .clear
        floor.zPosition = -90
        addChild(floor)
        self.floor = floor

        let rig = MoppetRig()
        world.addChild(rig.root)
        addChild(world)
        self.rig = rig

        layout()
        rig.apply(pose: latestPose)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    /// Fit the puppet to whatever surface it landed on. The same scene runs full-bleed
    /// on an external display and in a half-height panel on a phone.
    private func layout() {
        guard size.width > 0, size.height > 0 else { return }

        let floorY = size.height * 0.16
        let available = size.height - floorY - size.height * 0.05
        let scale = min(size.width / designWidth, available / designHeight)

        world.setScale(max(scale, 0.05))
        world.position = CGPoint(x: size.width / 2, y: floorY)

        backdrop?.size = size
        backdrop?.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdrop?.texture = ParticleTextures.gradient(
            size: CGSize(width: 16, height: max(size.height, 16)),
            top: MoppetPalette.stageBottom,
            bottom: MoppetPalette.stageTop)

        // A soft floor band, so the puppet is standing on something rather than floating.
        floor?.path = CGPath(ellipseIn: CGRect(x: -size.width * 0.25,
                                               y: floorY - size.height * 0.55,
                                               width: size.width * 1.5,
                                               height: size.height * 0.55), transform: nil)
    }

    // MARK: PuppetRenderer

    func apply(pose: PuppetPose) {
        latestPose = pose
        rig?.apply(pose: pose)
    }

    func fire(effect: PuppetEffect) {
        guard let rig, let emitter = makeEmitter(for: effect) else { return }
        emitter.position = rig.root.position
        emitter.targetNode = world
        world.addChild(emitter)
        // Emitters are one-shot: let them empty, then clean themselves up.
        emitter.run(.sequence([
            .wait(forDuration: 0.12),
            .run { emitter.particleBirthRate = 0 },
            .wait(forDuration: 2.4),
            .removeFromParent(),
        ]))
    }

    private func makeEmitter(for effect: PuppetEffect) -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.zPosition = 5

        switch effect {
        case .dustPuff:
            emitter.particleTexture = ParticleTextures.soft(radius: 22, color: .white)
            emitter.particleBirthRate = 260
            emitter.particleLifetime = 0.55
            emitter.particleLifetimeRange = 0.25
            emitter.particlePositionRange = CGVector(dx: 150, dy: 10)
            emitter.particleSpeed = 90
            emitter.particleSpeedRange = 60
            emitter.emissionAngle = 0
            emitter.emissionAngleRange = .pi
            emitter.yAcceleration = 40
            emitter.particleAlpha = 0.55
            emitter.particleAlphaSpeed = -1.2
            emitter.particleScale = 0.5
            emitter.particleScaleRange = 0.35
            emitter.particleScaleSpeed = 0.8
            emitter.particleColor = MoppetPalette.floor
            emitter.particleColorBlendFactor = 0.8

        case .sparkle:
            emitter.particleTexture = ParticleTextures.soft(radius: 12, color: .white)
            emitter.particleBirthRate = 120
            emitter.particleLifetime = 0.8
            emitter.particlePositionRange = CGVector(dx: 210, dy: 260)
            emitter.position = CGPoint(x: 0, y: 260)
            emitter.particleSpeed = 30
            emitter.emissionAngleRange = .pi * 2
            emitter.particleAlpha = 0.9
            emitter.particleAlphaSpeed = -1.1
            emitter.particleScale = 0.35
            emitter.particleScaleRange = 0.2
            emitter.particleScaleSpeed = -0.25
            emitter.particleColor = MoppetPalette.hair
            emitter.particleColorBlendFactor = 1

        case .confetti:
            emitter.particleTexture = ParticleTextures.chip(size: 14, color: .white)
            emitter.particleBirthRate = 320
            emitter.particleLifetime = 2.2
            emitter.particlePositionRange = CGVector(dx: 260, dy: 20)
            emitter.position = CGPoint(x: 0, y: 620)
            emitter.particleSpeed = 60
            emitter.particleSpeedRange = 50
            emitter.emissionAngle = -.pi / 2
            emitter.emissionAngleRange = .pi / 3
            emitter.yAcceleration = -180
            emitter.particleAlpha = 1
            emitter.particleAlphaSpeed = -0.35
            emitter.particleScale = 0.7
            emitter.particleRotationRange = .pi * 2
            emitter.particleRotationSpeed = 4
            emitter.particleColorSequence = nil
            emitter.particleColor = MoppetPalette.hair
            emitter.particleColorBlendFactor = 1
        }
        return emitter
    }
}
