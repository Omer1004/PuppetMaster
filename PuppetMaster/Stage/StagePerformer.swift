import SpriteKit

/// One puppet's place on a stage.
///
/// This is the ``PuppetRenderer`` the engine actually talks to. It was split out of
/// ``PuppetScene`` when a second puppet arrived: the scene owns the things a *stage* has
/// — sky, floor, stars — and a performer owns the things a *puppet* has, so putting two
/// on one stage means adding a performer rather than adding a scene.
///
/// Each performer is driven by its own engine. Nothing here knows that, which is why two
/// puppets cannot drift out of step with their own poses.
@MainActor
final class StagePerformer: PuppetRenderer {

    /// Everything this puppet draws hangs off here. The scene positions and scales it.
    let world = SKNode()

    private var rig: PuppetRig?
    private var pendingCharacter: CharacterDescriptor?
    private var latestPose: PuppetPose = .neutral
    private var home: CGPoint = .zero
    private var baseScale: CGFloat = 1

    /// Set by the scene; needed for the dust colour, which has to sit against the floor.
    var backdrop: Backdrop = BackdropLibrary.default
    /// Called when this performer needs the stage relaid out — a new character has
    /// different proportions and may need a different scale.
    var onNeedsLayout: (() -> Void)?
    /// Whether this scene is attached to a view yet. A rig built with no view has no
    /// size to lay out against.
    var isLive = false

    var designWidth: CGFloat { rig?.designWidth ?? 300 }
    var designHeight: CGFloat { rig?.designHeight ?? 470 }
    var headHeight: CGFloat { rig?.headHeight ?? 250 }

    // MARK: Attention

    /// In a duet the performer needs to know which puppet their thumbs are driving, and
    /// the audience should not be shown a debug highlight to tell them. Staging answers
    /// both: the one being driven stands slightly downstage, brighter and larger. It
    /// reads as depth rather than as a selection.
    func setFocused(_ focused: Bool, animated: Bool) {
        let alpha: CGFloat = focused ? 1 : 0.72
        let scale = baseScale * (focused ? 1 : 0.92)
        guard animated else {
            world.alpha = alpha
            world.setScale(scale)
            return
        }
        world.run(.group([.fadeAlpha(to: alpha, duration: 0.22),
                          .scale(to: scale, duration: 0.22)]))
    }

    /// Put the puppet in its slot. Called by the scene's layout, never by the engine.
    func place(at home: CGPoint, scale: CGFloat, focused: Bool) {
        self.home = home
        self.baseScale = scale
        if world.action(forKey: Self.shakeKey) == nil { world.position = home }
        setFocused(focused, animated: false)
    }

    // MARK: PuppetRenderer

    func load(character: CharacterDescriptor) {
        guard isLive else {
            pendingCharacter = character
            return
        }
        build(character: character)
    }

    /// Drain a character that arrived while there was no view to build it against.
    func becameLive() {
        isLive = true
        guard let pendingCharacter else { return }
        self.pendingCharacter = nil
        build(character: pendingCharacter)
    }

    private func build(character: CharacterDescriptor) {
        rig?.root.removeFromParent()
        let rig = PuppetRig(character: character)
        world.addChild(rig.root)
        self.rig = rig
        onNeedsLayout?()
        rig.apply(pose: latestPose)
    }

    func setBackdrop(_ backdrop: Backdrop) {
        // The stage owns the sky; a performer only needs to know what colour it kicks up.
        self.backdrop = backdrop
    }

    func apply(pose: PuppetPose) {
        latestPose = pose
        rig?.apply(pose: pose)
    }

    func fire(effect: PuppetEffect) {
        guard rig != nil else { return }
        // Do NOT set `position` here: each effect chooses its own spawn point in
        // `makeEmitter` (dust at the feet, sparkle at the head, confetti from above),
        // and the world node is always at the puppet's feet.
        switch effect {
        case .impact:   shake(11)
        case .dustPuff: shake(4)
        default:        break
        }

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

    // MARK: Shake

    private static let shakeKey = "shake"

    /// A short, decaying jolt. Weight is invisible in a 2D puppet until something it
    /// does moves the world — this is the cheapest way to make a landing land.
    ///
    /// It shakes this performer, not the stage: in a duet, one puppet landing must not
    /// jolt the other one, or neither reads as a separate body.
    private func shake(_ intensity: CGFloat) {
        world.removeAction(forKey: Self.shakeKey)
        var steps: [SKAction] = []
        let count = 7
        for i in 0..<count {
            let decay = 1 - CGFloat(i) / CGFloat(count)
            steps.append(.move(to: CGPoint(
                x: home.x + .random(in: -1...1) * intensity * decay,
                y: home.y + .random(in: -1...1) * intensity * decay * 0.55),
                duration: 0.028))
        }
        steps.append(.move(to: home, duration: 0.05))
        world.run(.sequence(steps), withKey: Self.shakeKey)
    }

    // MARK: Emitters

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
        let headY = headHeight

        switch effect {
        case .dustPuff, .impact:
            let heavy = effect == .impact
            emitter.particleTexture = ParticleTextures.soft(radius: heavy ? 28 : 22, color: .white)
            emitter.particleBirthRate = heavy ? 460 : 260
            emitter.particleLifetime = 0.55
            emitter.particleLifetimeRange = 0.25
            emitter.particlePositionRange = CGVector(dx: heavy ? 200 : 150, dy: 10)
            emitter.particleSpeed = heavy ? 140 : 90
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
