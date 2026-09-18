import SpriteKit

/// One cut-out puppet, built from a ``CharacterDescriptor``.
///
/// A puppet is a hierarchy of parts with pivots, which is exactly what an `SKNode` tree
/// is — that correspondence is why SpriteKit was chosen for the stage (ARCHITECTURE §7).
///
/// There is one rig for the whole cast. Every character produces the same node
/// hierarchy and only the numbers differ, which is what makes "characters are content,
/// not code" true rather than aspirational. The rig has no opinion about *why* a jaw is
/// open or an arm is raised; it only binds ``PoseChannel`` values onto transforms.
@MainActor
final class PuppetRig {

    /// Everything hangs off here, at the puppet's floor contact point, so
    /// `bodyRotation` topples it around its base rather than its middle.
    let root = SKNode()

    /// Total drawn height, used by the scene to fit any character to any surface.
    private(set) var designHeight: CGFloat = 470
    private(set) var designWidth: CGFloat = 300
    /// Roughly where the head is, so head-height effects land in the right place.
    private(set) var headHeight: CGFloat = 250

    private let character: CharacterDescriptor

    private let puppet = SKNode()        // bodyOffset + bodyRotation
    private let squashNode = SKNode()    // squash / stretch
    private let body = SKNode()          // bodyLean
    private let headPivot = SKNode()     // headTilt
    private let face = SKNode()          // headTurn / headNod parallax
    private let crestPivot = SKNode()

    private let shadow = SKShapeNode()
    private let armLeftPivot = SKNode()
    private let armRightPivot = SKNode()

    private let eyeLeft: Eye
    private let eyeRight: Eye
    private let browLeft = SKShapeNode()
    private let browRight = SKShapeNode()

    private let mouthPivot = SKNode()    // jaw opens downward from here
    private let mouthInterior = SKShapeNode()
    private let tongue = SKShapeNode()
    private let smileArc = SKShapeNode()

    private let headBaseY: CGFloat

    // MARK: Build

    init(character: CharacterDescriptor) {
        self.character = character
        headBaseY = CGFloat(character.head.centerY)
        eyeLeft = Eye(radius: CGFloat(character.eyes.leftRadius), descriptor: character)
        eyeRight = Eye(radius: CGFloat(character.eyes.rightRadius), descriptor: character)

        buildShadow()
        buildBody()
        buildHead()

        root.addChild(shadow)
        root.addChild(puppet)
        puppet.addChild(squashNode)
        squashNode.addChild(body)

        measure()
    }

    private var palette: CharacterDescriptor.Palette { character.palette }

    /// Work out the drawn bounds so the scene can scale any character to fit. Computed
    /// from the descriptor rather than from node frames, which are pose-dependent.
    private func measure() {
        let head = character.head
        // Only reserve headroom for a crest that exists, or a bare-headed character is
        // scaled down to leave empty space above it.
        let crestTop = character.crest.kind == .none
            ? 0
            : head.centerY + character.crest.offsetY + 70 * character.crest.size
        headHeight = CGFloat(head.centerY)
        designHeight = CGFloat(max(head.centerY + head.halfHeight, crestTop)) + 40
        designWidth = CGFloat(max(character.body.waistHalfWidth,
                                  head.halfWidth,
                                  character.arms.shoulder.x + character.arms.thickness)) * 2 + 60
    }

    private func buildShadow() {
        let w = CGFloat(character.body.baseHalfWidth) * 2.2
        shadow.path = CGPath(ellipseIn: CGRect(x: -w / 2, y: -17, width: w, height: 34), transform: nil)
        shadow.fillColor = UIColor(white: 0, alpha: 0.16)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        shadow.position = CGPoint(x: 0, y: 6)
    }

    private func buildBody() {
        let b = character.body
        let h = CGFloat(b.height)
        let waist = CGFloat(b.waistHalfWidth)
        let shoulder = CGFloat(b.shoulderHalfWidth)
        let base = CGFloat(b.baseHalfWidth)

        // Soft tapered sock shape with a rounded base, so the puppet can bob and topple
        // without ever needing legs or a walk cycle.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -base, y: 24))
        path.addQuadCurve(to: CGPoint(x: -shoulder, y: h), control: CGPoint(x: -waist, y: h * 0.72))
        path.addQuadCurve(to: CGPoint(x: shoulder, y: h), control: CGPoint(x: 0, y: h * 1.14))
        path.addQuadCurve(to: CGPoint(x: base, y: 24), control: CGPoint(x: waist, y: h * 0.72))
        path.addQuadCurve(to: CGPoint(x: base * 0.63, y: 5), control: CGPoint(x: base, y: -2))
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: base * 0.36, y: -4))
        path.addQuadCurve(to: CGPoint(x: -base * 0.63, y: 5), control: CGPoint(x: -base * 0.36, y: -4))
        path.addQuadCurve(to: CGPoint(x: -base, y: 24), control: CGPoint(x: -base, y: -2))
        path.closeSubpath()

        let torso = SKShapeNode(path: path)
        torso.fillColor = palette.fur.uiColor
        torso.strokeColor = palette.outline.uiColor
        torso.lineWidth = 3
        torso.lineJoin = .round
        body.addChild(torso)

        let bellyPatch = SKShapeNode(ellipseIn: CGRect(
            x: -CGFloat(b.bellyWidth) / 2,
            y: CGFloat(b.bellyCenterY) - CGFloat(b.bellyHeight) / 2,
            width: CGFloat(b.bellyWidth), height: CGFloat(b.bellyHeight)))
        bellyPatch.fillColor = palette.belly.uiColor
        bellyPatch.strokeColor = .clear
        bellyPatch.zPosition = 1
        body.addChild(bellyPatch)

        buildArm(pivot: armLeftPivot, mirrored: true)
        buildArm(pivot: armRightPivot, mirrored: false)
        body.addChild(armLeftPivot)
        body.addChild(armRightPivot)
    }

    /// Stubby felt arm, drawn hanging straight down from its shoulder pivot so that
    /// `zRotation` maps directly onto the `armLeft` / `armRight` channels.
    private func buildArm(pivot: SKNode, mirrored: Bool) {
        let a = character.arms
        let w = CGFloat(a.thickness)
        let length = CGFloat(a.length)

        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: -w, y: -length, width: w * 2, height: length + 12),
                            cornerWidth: w, cornerHeight: w)
        let arm = SKShapeNode(path: path)
        arm.fillColor = palette.fur.uiColor
        arm.strokeColor = palette.outline.uiColor
        arm.lineWidth = 3
        pivot.addChild(arm)
        pivot.position = CGPoint(x: mirrored ? -CGFloat(a.shoulder.x) : CGFloat(a.shoulder.x),
                                 y: CGFloat(a.shoulder.y))
        pivot.zPosition = mirrored ? 0.5 : 2
    }

    private func buildHead() {
        let h = character.head
        headPivot.position = CGPoint(x: 0, y: headBaseY)
        headPivot.zPosition = 3
        body.addChild(headPivot)

        let skull = SKShapeNode(ellipseIn: CGRect(
            x: -CGFloat(h.halfWidth), y: -CGFloat(h.halfHeight),
            width: CGFloat(h.halfWidth) * 2, height: CGFloat(h.halfHeight) * 2))
        skull.fillColor = palette.fur.uiColor
        skull.strokeColor = palette.outline.uiColor
        skull.lineWidth = 3
        headPivot.addChild(skull)

        buildCrest()
        headPivot.addChild(crestPivot)
        headPivot.addChild(face)

        buildMouth()
        buildEyes()
    }

    /// What sits on top of the head — the cheapest way to make characters built from one
    /// rig read as different species.
    private func buildCrest() {
        let c = character.crest
        let s = CGFloat(c.size)
        crestPivot.position = CGPoint(x: 0, y: CGFloat(c.offsetY))
        crestPivot.zPosition = -0.5

        switch c.kind {
        case .none:
            return

        case .tuft:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -26 * s, y: 0))
            path.addQuadCurve(to: CGPoint(x: -6 * s, y: 66 * s), control: CGPoint(x: -34 * s, y: 44 * s))
            path.addQuadCurve(to: CGPoint(x: 8 * s, y: 26 * s), control: CGPoint(x: 4 * s, y: 44 * s))
            path.addQuadCurve(to: CGPoint(x: 34 * s, y: 58 * s), control: CGPoint(x: 22 * s, y: 50 * s))
            path.addQuadCurve(to: CGPoint(x: 26 * s, y: 0), control: CGPoint(x: 40 * s, y: 26 * s))
            path.closeSubpath()
            addCrestShape(path, filled: true)

        case .ears:
            // Long and droopy, hung from the top corners of the head. They swing a beat
            // behind everything, which is most of why Bramble reads as slow.
            let spread = CGFloat(character.head.halfWidth) * 0.62
            for side in [-1.0, 1.0] as [CGFloat] {
                let path = CGMutablePath()
                path.addRoundedRect(
                    in: CGRect(x: -13 * s, y: -18 * s, width: 26 * s, height: 96 * s),
                    cornerWidth: 13 * s, cornerHeight: 13 * s)
                let ear = SKShapeNode(path: path)
                ear.fillColor = palette.accent.uiColor
                ear.strokeColor = palette.accent.shaded(0.28).uiColor
                ear.lineWidth = 3
                ear.position = CGPoint(x: side * spread, y: -10 * s)
                ear.zRotation = side * 0.34
                crestPivot.addChild(ear)
            }

        case .antenna:
            let stalk = SKShapeNode(path: CGPath(roundedRect:
                CGRect(x: -3.5 * s, y: 0, width: 7 * s, height: 44 * s),
                cornerWidth: 3.5 * s, cornerHeight: 3.5 * s, transform: nil))
            stalk.fillColor = palette.accent.shaded(0.15).uiColor
            stalk.strokeColor = .clear
            crestPivot.addChild(stalk)

            let bobble = SKShapeNode(circleOfRadius: 15 * s)
            bobble.position = CGPoint(x: 0, y: 52 * s)
            bobble.fillColor = palette.accent.uiColor
            bobble.strokeColor = palette.accent.shaded(0.3).uiColor
            bobble.lineWidth = 3
            crestPivot.addChild(bobble)

        case .spikes:
            let span = CGFloat(character.head.halfWidth) * 0.58
            let path = CGMutablePath()
            for i in 0..<5 {
                let t = CGFloat(i) / 4
                let x = -span + span * 2 * t
                let height = (i % 2 == 0 ? 42 : 30) * s
                path.move(to: CGPoint(x: x - 17 * s, y: -6))
                path.addLine(to: CGPoint(x: x, y: height))
                path.addLine(to: CGPoint(x: x + 17 * s, y: -6))
                path.closeSubpath()
            }
            addCrestShape(path, filled: true)
        }
    }

    private func addCrestShape(_ path: CGPath, filled: Bool) {
        let node = SKShapeNode(path: path)
        node.fillColor = filled ? palette.accent.uiColor : .clear
        node.strokeColor = palette.accent.shaded(0.3).uiColor
        node.lineWidth = 2
        node.lineJoin = .round
        crestPivot.addChild(node)
    }

    private func buildEyes() {
        let e = character.eyes
        eyeLeft.node.position = CGPoint(x: CGFloat(e.leftCenter.x), y: CGFloat(e.leftCenter.y))
        eyeRight.node.position = CGPoint(x: CGFloat(e.rightCenter.x), y: CGFloat(e.rightCenter.y))
        face.addChild(eyeLeft.node)
        face.addChild(eyeRight.node)

        let b = character.brows
        for (brow, x, width) in [(browLeft, CGFloat(e.leftCenter.x), CGFloat(b.leftWidth)),
                                 (browRight, CGFloat(e.rightCenter.x), CGFloat(b.rightWidth))] {
            let t = CGFloat(b.thickness)
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: -width / 2, y: -t / 2, width: width, height: t),
                                cornerWidth: t / 2, cornerHeight: t / 2)
            brow.path = path
            brow.fillColor = palette.outline.uiColor
            brow.strokeColor = .clear
            brow.position = CGPoint(x: x, y: CGFloat(b.centerY))
            brow.zPosition = 2
            face.addChild(brow)
        }
    }

    private func buildMouth() {
        let m = character.mouth
        let halfWidth = CGFloat(m.halfWidth)
        let depth = CGFloat(m.depth)

        mouthPivot.position = CGPoint(x: 0, y: CGFloat(m.centerY))
        mouthPivot.zPosition = 1
        face.addChild(mouthPivot)

        // The interior hangs *downward* from the pivot, so scaling it on Y opens the
        // mouth from a fixed upper lip — which is how a real jaw hinges.
        mouthInterior.path = CGPath(ellipseIn: CGRect(
            x: -halfWidth, y: -depth, width: halfWidth * 2, height: depth + 8), transform: nil)
        mouthInterior.fillColor = palette.mouthInterior.uiColor
        mouthInterior.strokeColor = palette.outline.uiColor
        // The outline is the lip. A separate lip node would sit where the ellipse has
        // narrowed to a point and read as a bar across the mouth.
        mouthInterior.lineWidth = CGFloat(m.lipThickness) * 0.32 + 2
        mouthPivot.addChild(mouthInterior)


        // Tongue and smile line live OUTSIDE the jaw pivot: inside it they would inherit
        // the jaw's vertical scale and be squashed to nothing exactly when a closed-mouth
        // expression needs them most.
        let tw = halfWidth * 0.52
        tongue.path = CGPath(ellipseIn: CGRect(
            x: -tw, y: -tw * 1.5, width: tw * 2, height: tw * 1.75), transform: nil)
        tongue.fillColor = palette.tongue.uiColor
        tongue.strokeColor = palette.outline.uiColor
        tongue.lineWidth = 3
        tongue.zPosition = 1.6
        face.addChild(tongue)

        smileArc.strokeColor = palette.outline.uiColor
        smileArc.lineWidth = 5
        smileArc.lineCap = .round
        smileArc.fillColor = .clear
        smileArc.zPosition = 1.4
        face.addChild(smileArc)
    }

    // MARK: Apply

    /// Bind one frame of pose onto the node tree. Called once per surface per frame.
    func apply(pose: PuppetPose) {
        let jaw = CGFloat(pose[.jawOpen])
        let smile = CGFloat(pose[.mouthSmile])
        let m = character.mouth

        puppet.position = CGPoint(x: CGFloat(pose[.bodyOffsetX]), y: CGFloat(pose[.bodyOffsetY]))
        puppet.zRotation = CGFloat(pose[.bodyRotation])

        // Squash and stretch, roughly volume-preserving so the puppet keeps its mass.
        let s = CGFloat(pose[.squash])
        squashNode.yScale = s
        squashNode.xScale = 1 / pow(s, 0.62)

        body.zRotation = CGFloat(pose[.bodyLean])

        headPivot.zRotation = CGFloat(pose[.headTilt])
        headPivot.position = CGPoint(x: 0, y: headBaseY + CGFloat(pose[.headNod]) * 9)

        // Head turn is faked with parallax on the face rather than a redraw: the features
        // slide, which reads as a turn at this level of stylisation.
        face.position = CGPoint(x: CGFloat(pose[.headTurn]) * 17,
                                y: CGFloat(pose[.headNod]) * 11)

        let swing = CGFloat(character.crest.swing)
        crestPivot.zRotation = CGFloat(pose[.hairLag]) * 0.42 * swing
        crestPivot.xScale = 1 - abs(CGFloat(pose[.hairLag])) * 0.08

        armLeftPivot.zRotation = CGFloat(pose[.armLeft])
        armRightPivot.zRotation = CGFloat(pose[.armRight])

        shadow.xScale = CGFloat(pose[.shadowScale])
        shadow.yScale = CGFloat(pose[.shadowScale])
        shadow.alpha = 0.35 + CGFloat(pose[.shadowScale]) * 0.65

        // Mouth. A closed mouth is a thin line, not a zero-height ellipse.
        let open = 0.055 + jaw * 0.945
        mouthPivot.yScale = open
        mouthPivot.xScale = 1 + smile * 0.09 - jaw * 0.05
        // The pivot's vertical squash would otherwise thin the outline as the mouth shuts.
        mouthInterior.lineWidth = (CGFloat(m.lipThickness) * 0.32 + 2) / max(open, 0.25)

        let tongueOut = CGFloat(pose[.tongueOut])
        tongue.position = CGPoint(
            x: CGFloat(pose[.gazeX]) * 9,
            y: CGFloat(m.centerY) + 2 - tongueOut * 10 - jaw * CGFloat(m.depth) * 0.26)
        tongue.alpha = max(tongueOut, jaw * 0.85)
        tongue.setScale(0.6 + tongueOut * 0.4)
        tongue.zRotation = CGFloat(pose[.gazeX]) * 0.12

        updateSmile(smile: smile, jaw: jaw)

        eyeLeft.apply(pose: pose)
        eyeRight.apply(pose: pose)
        applyBrows(pose: pose)
    }

    private func updateSmile(smile: CGFloat, jaw: CGFloat) {
        // A curve under the mouth: up for a smile, down for a frown. It fades out as the
        // mouth opens, where the interior shape carries the expression instead.
        let halfWidth = CGFloat(character.mouth.halfWidth) * 0.94
        let y = CGFloat(character.mouth.centerY) - 18
        let path = CGMutablePath()
        let lift = smile * 26
        path.move(to: CGPoint(x: -halfWidth, y: y))
        path.addQuadCurve(to: CGPoint(x: halfWidth, y: y), control: CGPoint(x: 0, y: y - lift))
        smileArc.path = path
        smileArc.alpha = max(0, 1 - jaw * 3.5) * min(1, abs(smile) * 1.6)
    }

    private func applyBrows(pose: PuppetPose) {
        let lift = CGFloat(pose[.browLift])
        let angle = CGFloat(pose[.browAngle])
        let b = character.brows
        let e = character.eyes
        browLeft.position = CGPoint(x: CGFloat(e.leftCenter.x), y: CGFloat(b.centerY) + lift * 16)
        browRight.position = CGPoint(x: CGFloat(e.rightCenter.x), y: CGFloat(b.centerY) + lift * 16)
        browLeft.zRotation = angle * 0.42
        browRight.zRotation = -angle * 0.42
    }
}

// MARK: - Eye

/// One eye: white, a pupil that tracks gaze, and a lid that drops from the top.
@MainActor
private final class Eye {
    let node = SKNode()
    private let pupil = SKShapeNode()
    private let lid = SKShapeNode()
    private let radius: CGFloat
    private let lidRest: CGFloat

    init(radius: CGFloat, descriptor: CharacterDescriptor) {
        self.radius = radius
        self.lidRest = CGFloat(descriptor.eyes.lidRest)
        let palette = descriptor.palette

        let white = SKShapeNode(path: CGPath(ellipseIn:
            CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil))
        white.fillColor = palette.eyeWhite.uiColor
        white.strokeColor = palette.outline.uiColor
        white.lineWidth = 3
        node.addChild(white)

        let pr = radius * CGFloat(descriptor.eyes.pupilRatio)
        pupil.path = CGPath(ellipseIn: CGRect(x: -pr, y: -pr, width: pr * 2, height: pr * 2), transform: nil)
        pupil.fillColor = palette.pupil.uiColor
        pupil.strokeColor = .clear
        pupil.zPosition = 1
        node.addChild(pupil)

        // Catchlight. One highlight is the difference between an eye and a dot.
        let gr = radius * 0.16
        let glint = SKShapeNode(ellipseIn: CGRect(x: pr * 0.1, y: pr * 0.25, width: gr * 2, height: gr * 2))
        glint.fillColor = .white
        glint.strokeColor = .clear
        pupil.addChild(glint)

        // The lid hangs from the top of the eye and scales down over it.
        lid.path = CGPath(ellipseIn: CGRect(x: -radius - 1, y: -radius * 2,
                                            width: radius * 2 + 2, height: radius * 2 + 2), transform: nil)
        lid.fillColor = palette.fur.uiColor
        lid.strokeColor = .clear
        lid.position = CGPoint(x: 0, y: radius)
        lid.zPosition = 2
        lid.yScale = lidRest
        node.addChild(lid)
    }

    func apply(pose: PuppetPose) {
        pupil.position = CGPoint(x: CGFloat(pose[.gazeX]) * radius * 0.42,
                                 y: CGFloat(pose[.gazeY]) * radius * 0.36)
        // Heavy-lidded characters never fully open, but a blink still closes them.
        lid.yScale = max(CGFloat(pose[.blink]), lidRest)
    }
}
