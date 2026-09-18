import SpriteKit

/// Moppet, as a cut-out puppet rig.
///
/// A puppet is a hierarchy of parts with pivots, which is exactly what an `SKNode`
/// tree is — that correspondence is the whole reason SpriteKit was chosen for the
/// stage (ARCHITECTURE §7).
///
/// The only thing this type does is bind ``PoseChannel`` values onto node transforms.
/// It has no opinion about *why* the jaw is open or the arm is raised, which is what
/// keeps the engine and the renderer independent.
@MainActor
final class MoppetRig {

    /// Everything hangs off here. Positioned at the puppet's floor contact point, so
    /// `bodyRotation` topples around its base rather than its middle.
    let root = SKNode()

    private let shadow = SKShapeNode()
    private let puppet = SKNode()        // bodyOffset + bodyRotation
    private let squash = SKNode()        // squash / stretch
    private let body = SKNode()          // bodyLean
    private let headPivot = SKNode()     // headTilt
    private let face = SKNode()          // headTurn / headNod parallax
    private let hairPivot = SKNode()

    private let armLeftPivot = SKNode()
    private let armRightPivot = SKNode()

    private let eyeLeft: Eye
    private let eyeRight: Eye
    private let browLeft = SKShapeNode()
    private let browRight = SKShapeNode()

    private let mouthPivot = SKNode()    // jaw opens downward from here
    private let mouthInterior = SKShapeNode()
    private let lowerLip = SKShapeNode()
    private let tongue = SKShapeNode()
    private let smileArc = SKShapeNode()

    private let headBaseY: CGFloat = 248

    // MARK: Build

    init() {
        eyeLeft = Eye(radius: 34)
        eyeRight = Eye(radius: 23)

        buildShadow()
        buildBody()
        buildHead()

        root.addChild(shadow)
        root.addChild(puppet)
        puppet.addChild(squash)
        squash.addChild(body)
    }

    private func buildShadow() {
        shadow.path = CGPath(ellipseIn: CGRect(x: -96, y: -17, width: 192, height: 34), transform: nil)
        shadow.fillColor = MoppetPalette.shadow
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        shadow.position = CGPoint(x: 0, y: 6)
    }

    private func buildBody() {
        // Soft tapered sock shape: wide at the shoulders, narrowing to a rounded base
        // so the puppet can bob and topple without ever needing legs or a walk cycle.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -82, y: 24))
        path.addQuadCurve(to: CGPoint(x: -66, y: 208), control: CGPoint(x: -104, y: 150))
        path.addQuadCurve(to: CGPoint(x: 66, y: 208), control: CGPoint(x: 0, y: 236))
        path.addQuadCurve(to: CGPoint(x: 82, y: 24), control: CGPoint(x: 104, y: 150))
        path.addQuadCurve(to: CGPoint(x: 52, y: 5), control: CGPoint(x: 84, y: -2))
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 30, y: -4))
        path.addQuadCurve(to: CGPoint(x: -52, y: 5), control: CGPoint(x: -30, y: -4))
        path.addQuadCurve(to: CGPoint(x: -82, y: 24), control: CGPoint(x: -84, y: -2))
        path.closeSubpath()

        let torso = SKShapeNode(path: path)
        torso.fillColor = MoppetPalette.fur
        torso.strokeColor = MoppetPalette.furShade
        torso.lineWidth = 3
        torso.lineJoin = .round
        body.addChild(torso)

        let bellyPatch = SKShapeNode(ellipseIn: CGRect(x: -52, y: 26, width: 104, height: 140))
        bellyPatch.fillColor = MoppetPalette.belly
        bellyPatch.strokeColor = .clear
        bellyPatch.zPosition = 1
        body.addChild(bellyPatch)

        buildArm(pivot: armLeftPivot, at: CGPoint(x: -72, y: 172), mirrored: true)
        buildArm(pivot: armRightPivot, at: CGPoint(x: 72, y: 172), mirrored: false)
        body.addChild(armLeftPivot)
        body.addChild(armRightPivot)
    }

    /// Stubby felt arm, drawn hanging straight down from its shoulder pivot so that
    /// `zRotation` maps directly onto the `armLeft` / `armRight` channels.
    private func buildArm(pivot: SKNode, at point: CGPoint, mirrored: Bool) {
        let path = CGMutablePath()
        let w: CGFloat = 23
        path.addRoundedRect(in: CGRect(x: -w, y: -96, width: w * 2, height: 108),
                            cornerWidth: w, cornerHeight: w)
        let arm = SKShapeNode(path: path)
        arm.fillColor = MoppetPalette.fur
        arm.strokeColor = MoppetPalette.furShade
        arm.lineWidth = 3
        pivot.addChild(arm)
        pivot.position = point
        pivot.zPosition = mirrored ? 0.5 : 2
    }

    private func buildHead() {
        headPivot.position = CGPoint(x: 0, y: headBaseY)
        headPivot.zPosition = 3
        body.addChild(headPivot)

        let skull = SKShapeNode(ellipseIn: CGRect(x: -102, y: -92, width: 204, height: 184))
        skull.fillColor = MoppetPalette.fur
        skull.strokeColor = MoppetPalette.furShade
        skull.lineWidth = 3
        headPivot.addChild(skull)

        buildHair()
        headPivot.addChild(hairPivot)
        headPivot.addChild(face)

        buildMouth()
        buildEyes()
    }

    private func buildHair() {
        // One lagging tuft. Cheap secondary motion, disproportionate amount of life.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -26, y: 0))
        path.addQuadCurve(to: CGPoint(x: -6, y: 66), control: CGPoint(x: -34, y: 44))
        path.addQuadCurve(to: CGPoint(x: 8, y: 26), control: CGPoint(x: 4, y: 44))
        path.addQuadCurve(to: CGPoint(x: 34, y: 58), control: CGPoint(x: 22, y: 50))
        path.addQuadCurve(to: CGPoint(x: 26, y: 0), control: CGPoint(x: 40, y: 26))
        path.closeSubpath()

        let tuft = SKShapeNode(path: path)
        tuft.fillColor = MoppetPalette.hair
        tuft.strokeColor = .clear
        hairPivot.addChild(tuft)
        hairPivot.position = CGPoint(x: 4, y: 74)
        hairPivot.zPosition = -0.5
    }

    private func buildEyes() {
        // Mismatched eyes: every expression reads as slightly startled, for free.
        eyeLeft.node.position = CGPoint(x: -46, y: 26)
        eyeRight.node.position = CGPoint(x: 48, y: 20)
        face.addChild(eyeLeft.node)
        face.addChild(eyeRight.node)

        for (brow, x, width) in [(browLeft, CGFloat(-46), CGFloat(66)),
                                 (browRight, CGFloat(48), CGFloat(48))] {
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: -width / 2, y: -6, width: width, height: 12),
                                cornerWidth: 6, cornerHeight: 6)
            brow.path = path
            brow.fillColor = MoppetPalette.brow
            brow.strokeColor = .clear
            brow.position = CGPoint(x: x, y: 74)
            brow.zPosition = 2
            face.addChild(brow)
        }
    }

    private func buildMouth() {
        mouthPivot.position = CGPoint(x: 0, y: -22)
        mouthPivot.zPosition = 1
        face.addChild(mouthPivot)

        // The interior hangs *downward* from the pivot, so scaling it on Y opens the
        // mouth from a fixed upper lip — which is how a real jaw hinges.
        mouthInterior.path = CGPath(ellipseIn: CGRect(x: -62, y: -92, width: 124, height: 100),
                                    transform: nil)
        mouthInterior.fillColor = MoppetPalette.mouth
        mouthInterior.strokeColor = MoppetPalette.furShade
        mouthInterior.lineWidth = 3
        mouthPivot.addChild(mouthInterior)

        tongue.path = CGPath(ellipseIn: CGRect(x: -30, y: -46, width: 60, height: 54), transform: nil)
        tongue.fillColor = MoppetPalette.tongue
        tongue.strokeColor = MoppetPalette.furShade
        tongue.lineWidth = 3
        tongue.zPosition = 1.6
        face.addChild(tongue)

        lowerLip.path = CGPath(roundedRect: CGRect(x: -64, y: -11, width: 128, height: 20),
                               cornerWidth: 10, cornerHeight: 10, transform: nil)
        lowerLip.fillColor = MoppetPalette.fur
        lowerLip.strokeColor = MoppetPalette.furShade
        lowerLip.lineWidth = 3
        lowerLip.zPosition = 2
        mouthPivot.addChild(lowerLip)

        smileArc.strokeColor = MoppetPalette.furShade
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

        puppet.position = CGPoint(x: CGFloat(pose[.bodyOffsetX]), y: CGFloat(pose[.bodyOffsetY]))
        puppet.zRotation = CGFloat(pose[.bodyRotation])

        // Squash and stretch, roughly volume-preserving so the puppet keeps its mass.
        let s = CGFloat(pose[.squash])
        squash.yScale = s
        squash.xScale = 1 / pow(s, 0.62)

        body.zRotation = CGFloat(pose[.bodyLean])

        headPivot.zRotation = CGFloat(pose[.headTilt])
        headPivot.position = CGPoint(x: 0, y: headBaseY + CGFloat(pose[.headNod]) * 9)

        // Head turn is faked with parallax on the face rather than a redraw: the
        // features slide, which reads as a turn at this level of stylisation.
        face.position = CGPoint(x: CGFloat(pose[.headTurn]) * 17,
                                y: CGFloat(pose[.headNod]) * 11)

        hairPivot.zRotation = CGFloat(pose[.hairLag]) * 0.42
        hairPivot.xScale = 1 - abs(CGFloat(pose[.hairLag])) * 0.08

        armLeftPivot.zRotation = CGFloat(pose[.armLeft])
        armRightPivot.zRotation = CGFloat(pose[.armRight])

        shadow.xScale = CGFloat(pose[.shadowScale])
        shadow.yScale = CGFloat(pose[.shadowScale])
        shadow.alpha = 0.35 + CGFloat(pose[.shadowScale]) * 0.65

        // Mouth. A closed mouth is a thin line, not a zero-height ellipse.
        let open = 0.055 + jaw * 0.945
        mouthPivot.yScale = open
        mouthPivot.xScale = 1 + smile * 0.09 - jaw * 0.05
        lowerLip.position = CGPoint(x: 0, y: -88)
        lowerLip.yScale = 1 / open               // keep the lip its own thickness

        let tongueOut = CGFloat(pose[.tongueOut])
        tongue.position = CGPoint(x: CGFloat(pose[.gazeX]) * 9,
                                  y: -20 - tongueOut * 10 - jaw * 24)
        tongue.alpha = max(tongueOut, jaw * 0.85)
        tongue.setScale(0.6 + tongueOut * 0.4)
        tongue.zRotation = CGFloat(pose[.gazeX]) * 0.12

        updateSmile(smile: smile, jaw: jaw)

        eyeLeft.apply(pose: pose)
        eyeRight.apply(pose: pose)
        applyBrows(pose: pose)
    }

    private func updateSmile(smile: CGFloat, jaw: CGFloat) {
        // A curve drawn under the mouth: up for a smile, down for a frown. Fades out
        // as the mouth opens, where the interior shape carries the expression instead.
        let path = CGMutablePath()
        let lift = smile * 26
        path.move(to: CGPoint(x: -58, y: -42))
        path.addQuadCurve(to: CGPoint(x: 58, y: -42), control: CGPoint(x: 0, y: -42 - lift))
        smileArc.path = path
        smileArc.alpha = max(0, 1 - jaw * 3.5) * min(1, abs(smile) * 1.6)
    }

    private func applyBrows(pose: PuppetPose) {
        let lift = CGFloat(pose[.browLift])
        let angle = CGFloat(pose[.browAngle])
        browLeft.position = CGPoint(x: -46, y: 74 + lift * 16)
        browRight.position = CGPoint(x: 48, y: 74 + lift * 16)
        browLeft.zRotation = angle * 0.42
        browRight.zRotation = -angle * 0.42
    }
}

// MARK: - Eye

/// One eye: white, pupil that tracks gaze, and a lid that drops from the top.
@MainActor
private final class Eye {
    let node = SKNode()
    private let white = SKShapeNode()
    private let pupil = SKShapeNode()
    private let lid = SKShapeNode()
    private let radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius

        white.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius,
                                              width: radius * 2, height: radius * 2), transform: nil)
        white.fillColor = MoppetPalette.eyeWhite
        white.strokeColor = MoppetPalette.furShade
        white.lineWidth = 3
        node.addChild(white)

        let pr = radius * 0.46
        pupil.path = CGPath(ellipseIn: CGRect(x: -pr, y: -pr, width: pr * 2, height: pr * 2), transform: nil)
        pupil.fillColor = MoppetPalette.pupil
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
        lid.fillColor = MoppetPalette.fur
        lid.strokeColor = .clear
        lid.position = CGPoint(x: 0, y: radius)
        lid.zPosition = 2
        lid.yScale = 0
        node.addChild(lid)
    }

    func apply(pose: PuppetPose) {
        pupil.position = CGPoint(x: CGFloat(pose[.gazeX]) * radius * 0.42,
                                 y: CGFloat(pose[.gazeY]) * radius * 0.36)
        lid.yScale = CGFloat(pose[.blink])
    }
}
