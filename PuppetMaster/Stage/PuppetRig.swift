// PuppetRig.swift
import SpriteKit
import UIKit

/// One soft puppet, built entirely from character data.
///
/// Texture generation belongs to construction. Pose binding never creates paths,
/// textures, actions or animation state.
@MainActor
final class PuppetRig {
    let root = SKNode()

    private(set) var designHeight: CGFloat = 470
    private(set) var designWidth: CGFloat = 300
    private(set) var headHeight: CGFloat = 250

    private let character: CharacterDescriptor
    private let surface: CharacterDescriptor.Surface

    private let puppet = SKNode()
    private let squashNode = SKNode()
    private let body = SKNode()
    private let chest = SKNode()
    private let headPivot = SKNode()
    private let face = SKNode()
    private let crestPivot = SKNode()
    private let armLeftPivot = SKNode()
    private let armRightPivot = SKNode()

    private let shadow = SKNode()
    private let neckShadow = SKNode()
    private let browLeft = SKNode()
    private let browRight = SKNode()
    private let cheekLeft = SKNode()
    private let cheekRight = SKNode()
    private let mouthPivot = SKNode()
    private let smilePivot = SKNode()
    private let tonguePivot = SKNode()

    private let eyeLeft: PuppetEye
    private let eyeRight: PuppetEye

    private let headBaseY: CGFloat
    private let mouthDepth: CGFloat

    // MARK: Build

    init(character: CharacterDescriptor) {
        // Before anything is baked, including the eyes below. Everything this
        // initialiser draws is cached against this id.
        PuppetPaint.beginCharacter(character.id)
        self.character = character
        surface = character.surface ?? .init()
        headBaseY = CGFloat(character.head.centerY)

        // The old depths could put the opening below the chin, especially on Pip.
        // Leave enough fabric below the cavity to read as a padded lower jaw.
        mouthDepth = max(12, min(
            CGFloat(character.mouth.depth),
            CGFloat(character.head.halfHeight + character.mouth.centerY) - 14
        ))

        eyeLeft = PuppetEye(
            radius: CGFloat(character.eyes.leftRadius),
            character: character,
            side: -1
        )
        eyeRight = PuppetEye(
            radius: CGFloat(character.eyes.rightRadius),
            character: character,
            side: 1
        )

        root.addChild(shadow)
        root.addChild(puppet)
        puppet.addChild(squashNode)
        squashNode.addChild(body)
        body.addChild(chest)
        body.addChild(armLeftPivot)
        body.addChild(armRightPivot)
        body.addChild(neckShadow)
        body.addChild(headPivot)
        headPivot.addChild(crestPivot)
        headPivot.addChild(face)

        shadow.zPosition = -10
        chest.zPosition = 0
        armLeftPivot.zPosition = 2
        armRightPivot.zPosition = 2
        neckShadow.zPosition = 4
        headPivot.zPosition = 10
        crestPivot.zPosition = -1
        face.zPosition = 2

        buildBody()
        buildArms()
        buildHead()
        buildCrest()
        buildFace()
        buildShadow()

        apply(pose: .neutral)

        // Construction-time bounds include the actual crest, including tilted ears.
        let bounds = root.calculateAccumulatedFrame()
        designHeight = max(1, bounds.maxY + 30)
        designWidth = max(1, max(abs(bounds.minX), abs(bounds.maxX)) * 2 + 40)
        headHeight = headBaseY
    }

    private var palette: CharacterDescriptor.Palette { character.palette }

    private func buildBody() {
        let b = character.body
        let h = CGFloat(b.height)
        let waist = CGFloat(b.waistHalfWidth)
        let shoulder = CGFloat(b.shoulderHalfWidth)
        let base = CGFloat(b.baseHalfWidth)

        // Putting the waist on the contour, rather than using it only as a control
        // point, preserves the intended lanky/squat distinction at thumbnail size.
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addCurve(
            to: CGPoint(x: -base, y: 24),
            control1: CGPoint(x: -base * 0.8, y: -1),
            control2: CGPoint(x: -base, y: 4)
        )
        p.addCurve(
            to: CGPoint(x: -waist, y: h * 0.43),
            control1: CGPoint(x: -base, y: h * 0.20),
            control2: CGPoint(x: -waist, y: h * 0.27)
        )
        p.addCurve(
            to: CGPoint(x: -shoulder, y: h),
            control1: CGPoint(x: -waist, y: h * 0.72),
            control2: CGPoint(x: -shoulder * 1.13, y: h * 0.91)
        )
        p.addCurve(
            to: CGPoint(x: shoulder, y: h),
            control1: CGPoint(x: -shoulder * 0.45, y: h * 1.07),
            control2: CGPoint(x: shoulder * 0.45, y: h * 1.07)
        )
        p.addCurve(
            to: CGPoint(x: waist, y: h * 0.43),
            control1: CGPoint(x: shoulder * 1.13, y: h * 0.91),
            control2: CGPoint(x: waist, y: h * 0.72)
        )
        p.addCurve(
            to: CGPoint(x: base, y: 24),
            control1: CGPoint(x: waist, y: h * 0.27),
            control2: CGPoint(x: base, y: h * 0.20)
        )
        p.addCurve(
            to: .zero,
            control1: CGPoint(x: base, y: 4),
            control2: CGPoint(x: base * 0.8, y: -1)
        )
        p.closeSubpath()

        let bounds = p.boundingBoxOfPath.insetBy(dx: -6, dy: -6)
        let torso = PuppetPaint.bake(bounds: bounds) { context in
            PuppetPaint.felt(
                p, in: context, color: palette.fur,
                surface: surface, seed: 101,
                contour: palette.outline
            )

            let bellyRect = CGRect(
                x: -CGFloat(b.bellyWidth) / 2,
                y: CGFloat(b.bellyCenterY - b.bellyHeight / 2),
                width: CGFloat(b.bellyWidth),
                height: CGFloat(b.bellyHeight)
            )
            let patch = PuppetPaint.ellipse(bellyRect)

            context.saveGState()
            context.addPath(p)
            context.clip()

            PuppetPaint.felt(
                patch, in: context, color: palette.belly,
                surface: surface, seed: 102
            )

            // A broken, low-contrast seam suggests sewn felt without becoming
            // another heavy outline competing with the face.
            context.addPath(PuppetPaint.ellipse(
                bellyRect.insetBy(dx: 3.5, dy: 3.5)
            ))
            context.setStrokeColor(PuppetPaint.color(
                palette.belly.shaded(0.25), alpha: 0.45
            ))
            context.setLineWidth(0.8)
            context.setLineDash(phase: 0, lengths: [2, 4])
            context.strokePath()
            context.restoreGState()
        }
        chest.addChild(torso.node())
    }

    private func buildArms() {
        let a = character.arms
        let w = CGFloat(a.thickness)
        let length = CGFloat(a.length)

        let p = CGMutablePath()
        p.move(to: CGPoint(x: -w * 0.72, y: 8))
        p.addCurve(
            to: CGPoint(x: -w, y: -length + w),
            control1: CGPoint(x: -w * 0.96, y: -length * 0.3),
            control2: CGPoint(x: -w * 1.08, y: -length * 0.64)
        )
        p.addCurve(
            to: CGPoint(x: w, y: -length + w),
            control1: CGPoint(x: -w, y: -length - w * 0.2),
            control2: CGPoint(x: w, y: -length - w * 0.2)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.72, y: 8),
            control1: CGPoint(x: w * 0.95, y: -length * 0.6),
            control2: CGPoint(x: w * 0.82, y: -length * 0.2)
        )
        p.addQuadCurve(
            to: CGPoint(x: -w * 0.72, y: 8),
            control: CGPoint(x: 0, y: 20)
        )
        p.closeSubpath()

        let arm = PuppetPaint.bake(
            bounds: p.boundingBoxOfPath.insetBy(dx: -6, dy: -6)
        ) { context in
            PuppetPaint.felt(
                p, in: context, color: palette.fur,
                surface: surface, seed: 103,
                // Arms are the same fur as the torso they hang against. Without a
                // contour they are invisible, which is what happened.
                contour: palette.outline, contourWidth: 2.6
            )
            context.saveGState()
            context.addPath(p)
            context.clip()
            PuppetPaint.soft(
                in: context,
                rect: CGRect(x: -w * 1.4, y: -16, width: w * 2.8, height: 38),
                color: palette.fur.shaded(0.85),
                opacity: 0.38
            )
            context.restoreGState()
        }

        // Both arms share immutable pixels, but keep independent shoulder pivots.
        armLeftPivot.addChild(arm.node())
        armRightPivot.addChild(arm.node())
        armLeftPivot.position = CGPoint(
            x: -CGFloat(a.shoulder.x), y: CGFloat(a.shoulder.y)
        )
        armRightPivot.position = CGPoint(
            x: CGFloat(a.shoulder.x), y: CGFloat(a.shoulder.y)
        )
        armLeftPivot.zRotation = 0
        armRightPivot.zRotation = 0
    }

    private func buildHead() {
        let w = CGFloat(character.head.halfWidth)
        let h = CGFloat(character.head.halfHeight)

        // A broad crown and fuller lower cheeks read as a stuffed cushion rather
        // than a perfect vector ellipse. All proportions still come from the data.
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: h))
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.08),
            control1: CGPoint(x: w * 0.67, y: h * 1.03),
            control2: CGPoint(x: w, y: h * 0.66)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: -h),
            control1: CGPoint(x: w * 1.02, y: -h * 0.63),
            control2: CGPoint(x: w * 0.65, y: -h)
        )
        p.addCurve(
            to: CGPoint(x: -w, y: h * 0.08),
            control1: CGPoint(x: -w * 0.65, y: -h),
            control2: CGPoint(x: -w * 1.02, y: -h * 0.63)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: h),
            control1: CGPoint(x: -w, y: h * 0.66),
            control2: CGPoint(x: -w * 0.67, y: h * 1.03)
        )
        p.closeSubpath()

        let skull = PuppetPaint.bake(
            bounds: p.boundingBoxOfPath.insetBy(dx: -6, dy: -6)
        ) { context in
            PuppetPaint.felt(
                p, in: context, color: palette.fur,
                surface: surface, seed: 201,
                contour: palette.outline
            )
        }
        headPivot.addChild(skull.node())

        let contact = PuppetPaint.bake(
            bounds: CGRect(x: -w * 0.82, y: -16, width: w * 1.64, height: 32)
        ) { context in
            PuppetPaint.soft(
                in: context,
                rect: CGRect(x: -w * 0.82, y: -16, width: w * 1.64, height: 32),
                color: palette.fur.shaded(0.9),
                opacity: 0.42
            )
        }
        neckShadow.addChild(contact.node())
    }

    private func buildCrest() {
        let c = character.crest
        let s = CGFloat(c.size)
        let p = CGMutablePath()

        crestPivot.position.y = CGFloat(c.offsetY)

        // Nothing to draw, so draw nothing. This used to bake a 2x2 transparent texture
        // and add it at alpha 0 — invisible, but still a texture and still a node on the
        // path that builds a whole puppet.
        guard c.kind != .none else { return }

        switch c.kind {
        case .none:
            break

        case .tuft:
            p.move(to: CGPoint(x: -29 * s, y: -8 * s))
            p.addCurve(
                to: CGPoint(x: -12 * s, y: 66 * s),
                control1: CGPoint(x: -39 * s, y: 23 * s),
                control2: CGPoint(x: -26 * s, y: 57 * s)
            )
            p.addQuadCurve(
                to: CGPoint(x: 2 * s, y: 30 * s),
                control: CGPoint(x: -1 * s, y: 67 * s)
            )
            p.addQuadCurve(
                to: CGPoint(x: 31 * s, y: 55 * s),
                control: CGPoint(x: 19 * s, y: 57 * s)
            )
            p.addCurve(
                to: CGPoint(x: 27 * s, y: -8 * s),
                control1: CGPoint(x: 45 * s, y: 45 * s),
                control2: CGPoint(x: 40 * s, y: 9 * s)
            )
            p.closeSubpath()

        case .ears:
            // A flared, bent tip separates the ear silhouette from two straight
            // antennae and leaves a clear gap between the lobes.
            let spread = CGFloat(character.head.halfWidth) * 0.64
            for side: CGFloat in [-1, 1] {
                let ear = CGMutablePath()
                ear.move(to: CGPoint(x: -10 * s, y: -18 * s))
                ear.addCurve(
                    to: CGPoint(x: -16 * s, y: 64 * s),
                    control1: CGPoint(x: -14 * s, y: 10 * s),
                    control2: CGPoint(x: -26 * s, y: 51 * s)
                )
                ear.addCurve(
                    to: CGPoint(x: 16 * s, y: 63 * s),
                    control1: CGPoint(x: -9 * s, y: 87 * s),
                    control2: CGPoint(x: 21 * s, y: 85 * s)
                )
                ear.addCurve(
                    to: CGPoint(x: 10 * s, y: -18 * s),
                    control1: CGPoint(x: 9 * s, y: 33 * s),
                    control2: CGPoint(x: 13 * s, y: 6 * s)
                )
                ear.closeSubpath()
                let transform = CGAffineTransform(
                    translationX: side * spread, y: -8 * s
                ).rotated(by: -side * 0.30)
                p.addPath(ear, transform: transform)
            }

        case .antenna:
            p.addRoundedRect(
                in: CGRect(x: -5 * s, y: -8 * s, width: 10 * s, height: 62 * s),
                cornerWidth: 5 * s, cornerHeight: 5 * s
            )
            p.addEllipse(in: CGRect(
                x: -18 * s, y: 40 * s, width: 36 * s, height: 30 * s
            ))

        case .spikes:
            // Rounded tips retain the zigzag silhouette but read as sewn wedges.
            let span = CGFloat(character.head.halfWidth) * 0.65
            for i in 0..<5 {
                let x = -span + CGFloat(i) * span / 2
                let height: CGFloat = (i % 2 == 0 ? 43 : 30) * s
                p.move(to: CGPoint(x: x - 19 * s, y: -12 * s))
                p.addLine(to: CGPoint(x: x - 5 * s, y: height - 5 * s))
                p.addQuadCurve(
                    to: CGPoint(x: x + 5 * s, y: height - 5 * s),
                    control: CGPoint(x: x, y: height + 5 * s)
                )
                p.addLine(to: CGPoint(x: x + 19 * s, y: -12 * s))
                p.closeSubpath()
            }
        }

        let crest = PuppetPaint.bake(
            bounds: p.boundingBoxOfPath.insetBy(dx: -6, dy: -6)
        ) { context in
            PuppetPaint.felt(
                p, in: context, color: palette.accent,
                surface: surface, seed: 301,
                contour: palette.outline, contourWidth: 2.6
            )
        }
        crestPivot.addChild(crest.node())
    }

    private func buildFace() {
        buildMouth()

        let h = character.head
        let m = character.mouth
        let cheekX = min(
            CGFloat(h.halfWidth) * 0.72,
            CGFloat(m.halfWidth) + 15
        )
        let cheekY = CGFloat(m.centerY) + 7
        let cheekRect = CGRect(x: -20, y: -13, width: 40, height: 26)

        let cheek = PuppetPaint.bake(bounds: cheekRect) { context in
            PuppetPaint.soft(
                in: context, rect: cheekRect,
                color: surface.blush, opacity: 0.72
            )
        }

        for (node, side) in [(cheekLeft, CGFloat(-1)), (cheekRight, CGFloat(1))] {
            node.position = CGPoint(x: side * cheekX, y: cheekY)
            node.zPosition = 3
            node.addChild(cheek.node())
            face.addChild(node)
        }

        // A small padded muzzle anchors the nose without hiding the mouth corners.
        let mw = CGFloat(surface.muzzleWidth)
        let mh = CGFloat(surface.muzzleHeight)
        let muzzleRect = CGRect(x: -mw / 2, y: -mh / 2, width: mw, height: mh)
        let muzzle = PuppetPaint.bake(
            bounds: muzzleRect.insetBy(dx: -6, dy: -6)
        ) { context in
            PuppetPaint.felt(
                PuppetPaint.ellipse(muzzleRect),
                in: context, color: palette.fur.lightened(0.20),
                surface: surface, seed: 401
            )

            let nose = PuppetPaint.ellipse(CGRect(
                x: -mw * 0.18, y: -mh * 0.12,
                width: mw * 0.36, height: mh * 0.43
            ))
            PuppetPaint.felt(
                nose, in: context, color: palette.accent.shaded(0.36),
                surface: surface, seed: 402, fiberAmount: 0.35
            )
        }
        let muzzleNode = muzzle.node()
        muzzleNode.position.y += CGFloat(m.centerY) + mh * 0.65 + 6
        muzzleNode.zPosition = 4
        face.addChild(muzzleNode)

        let e = character.eyes
        eyeLeft.node.position = CGPoint(
            x: CGFloat(e.leftCenter.x), y: CGFloat(e.leftCenter.y)
        )
        eyeRight.node.position = CGPoint(
            x: CGFloat(e.rightCenter.x), y: CGFloat(e.rightCenter.y)
        )
        eyeLeft.node.zPosition = 6
        eyeRight.node.zPosition = 6
        face.addChild(eyeLeft.node)
        face.addChild(eyeRight.node)

        let b = character.brows
        for (node, width, seed) in [
            (browLeft, CGFloat(b.leftWidth), UInt64(403)),
            (browRight, CGFloat(b.rightWidth), UInt64(404))
        ] {
            let t = CGFloat(b.thickness)
            let rect = CGRect(x: -width / 2, y: -t / 2, width: width, height: t)
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: t / 2, cornerHeight: t / 2,
                transform: nil
            )
            let art = PuppetPaint.bake(bounds: rect.insetBy(dx: -5, dy: -5)) {
                context in
                PuppetPaint.felt(
                    path, in: context, color: palette.fur.shaded(0.58),
                    surface: surface, seed: seed
                )
            }
            node.addChild(art.node())
            node.zPosition = 8
            face.addChild(node)
        }
    }

    private func buildMouth() {
        let m = character.mouth
        let w = CGFloat(m.halfWidth)
        let d = mouthDepth
        let lip = max(2.5, CGFloat(m.lipThickness) * 0.23)
        let openingRect = CGRect(x: -w, y: -d, width: w * 2, height: d)
        let opening = PuppetPaint.ellipse(openingRect)

        let mouth = PuppetPaint.bake(
            bounds: openingRect.insetBy(dx: -lip - 5, dy: -lip - 5)
        ) { context in
            let rim = PuppetPaint.ellipse(
                openingRect.insetBy(dx: -lip, dy: -lip)
            )
            PuppetPaint.felt(
                rim, in: context, color: palette.fur.shaded(0.18),
                surface: surface, seed: 501
            )

            context.saveGState()
            context.addPath(opening)
            context.clip()

            // The roof absorbs light; the warmer floor makes the opening feel deep.
            PuppetPaint.linear(
                in: context, rect: openingRect,
                colors: [
                    palette.mouthInterior.shaded(0.86),
                    palette.mouthInterior.shaded(0.48),
                    palette.mouthInterior
                ],
                locations: [0, 0.58, 1]
            )

            let tongue = PuppetPaint.ellipse(CGRect(
                x: -w * 0.50, y: -d * 1.05,
                width: w, height: d * 0.46
            ))
            PuppetPaint.felt(
                tongue, in: context, color: palette.tongue,
                surface: surface, seed: 502, fiberAmount: 0
            )

            PuppetPaint.soft(
                in: context,
                rect: CGRect(x: -w, y: -d * 0.46, width: w * 2, height: d * 0.85),
                color: ColorSpec(0.04, 0.015, 0.025),
                opacity: 0.55
            )
            context.restoreGState()
        }

        mouthPivot.position.y = CGFloat(m.centerY)
        mouthPivot.zPosition = 1
        mouthPivot.addChild(mouth.node())
        face.addChild(mouthPivot)

        let smile = CGMutablePath()
        smile.move(to: CGPoint(x: -w * 0.91, y: 0))
        smile.addQuadCurve(
            to: CGPoint(x: w * 0.91, y: 0),
            control: CGPoint(x: 0, y: -22)
        )
        let seam = PuppetPaint.bake(
            bounds: CGRect(x: -w - 4, y: -15, width: w * 2 + 8, height: 20)
        ) { context in
            PuppetPaint.stroke(
                smile, in: context,
                color: palette.mouthInterior.shaded(0.7), width: 3.3
            )
        }
        smilePivot.position.y = CGFloat(m.centerY) - 1
        smilePivot.zPosition = 2
        smilePivot.addChild(seam.node())
        face.addChild(smilePivot)

        let tw = w * 0.27
        let length = min(36, d * 0.8)
        let tongueRect = CGRect(x: -tw, y: -length, width: tw * 2, height: length + 5)
        let tonguePath = CGPath(
            roundedRect: tongueRect,
            cornerWidth: tw * 0.8, cornerHeight: tw * 0.8,
            transform: nil
        )
        let protrudingTongue = PuppetPaint.bake(
            bounds: tongueRect.insetBy(dx: -5, dy: -5)
        ) { context in
            PuppetPaint.felt(
                tonguePath, in: context, color: palette.tongue,
                surface: surface, seed: 503, fiberAmount: 0
            )
            let crease = CGMutablePath()
            crease.move(to: CGPoint(x: 0, y: -length * 0.30))
            crease.addQuadCurve(
                to: CGPoint(x: 0, y: -length * 0.78),
                control: CGPoint(x: 1.5, y: -length * 0.55)
            )
            PuppetPaint.stroke(
                crease, in: context,
                color: palette.tongue.shaded(0.28), width: 1
            )
        }

        tonguePivot.addChild(protrudingTongue.node())
        tonguePivot.zPosition = 2.5
        face.addChild(tonguePivot)
    }

    private func buildShadow() {
        let w = CGFloat(character.body.baseHalfWidth)
        let rect = CGRect(x: -w * 1.38, y: -20, width: w * 2.76, height: 40)

        let art = PuppetPaint.bake(bounds: rect) { context in
            PuppetPaint.soft(
                in: context, rect: rect,
                color: ColorSpec(0.10, 0.065, 0.055), opacity: 0.22
            )
            PuppetPaint.soft(
                in: context,
                rect: CGRect(x: -w * 0.85, y: -7, width: w * 1.7, height: 14),
                color: ColorSpec(0.055, 0.035, 0.03), opacity: 0.29
            )
        }
        shadow.addChild(art.node())
    }

    // MARK: Apply

    /// Every visible response is a function of this pose, including the secondary
    /// shading. Reapplying a pose produces the same result regardless of history.
    func apply(pose: PuppetPose) {
        let jaw = unit(pose[.jawOpen])
        let tongueOut = unit(pose[.tongueOut])
        let smile = signed(pose[.mouthSmile])
        let turn = signed(pose[.headTurn])
        let nod = signed(pose[.headNod])
        let squash = CGFloat(pose[.squash]).clamped(to: 0.5...1.6)
        let breath = unit(pose[.breath])

        puppet.position = CGPoint(
            x: CGFloat(pose[.bodyOffsetX]),
            y: CGFloat(pose[.bodyOffsetY])
        )
        puppet.zRotation = CGFloat(pose[.bodyRotation])
        squashNode.yScale = squash
        squashNode.xScale = 1 / pow(squash, 0.62)
        body.zRotation = CGFloat(pose[.bodyLean])

        // Breathing expands the stuffed torso without dragging the facial features.
        chest.xScale = 1 + breath * 0.014
        chest.yScale = 1 + breath * 0.018

        headPivot.position = CGPoint(x: 0, y: headBaseY + nod * 9)
        headPivot.zRotation = CGFloat(pose[.headTilt])
        face.position = CGPoint(x: turn * 12, y: nod * 6)
        face.xScale = 1 - abs(turn) * 0.075

        neckShadow.position = CGPoint(
            x: -CGFloat(pose[.headTilt]) * 8,
            y: headPivot.position.y - CGFloat(character.head.halfHeight) + 3
        )
        neckShadow.xScale = 1 - max(0, nod) * 0.12
        neckShadow.alpha = 0.86 - nod * 0.10

        let lag = CGFloat(pose[.hairLag]).clamped(to: -1.5...1.5)
        crestPivot.zRotation = lag * 0.42 * CGFloat(character.crest.swing)
        crestPivot.xScale = 1 - abs(lag) * 0.06

        armLeftPivot.zRotation = CGFloat(pose[.armLeft])
        armRightPivot.zRotation = CGFloat(pose[.armRight])

        let contact = CGFloat(pose[.shadowScale]).clamped(to: 0...1.2)
        shadow.position.x = CGFloat(pose[.bodyOffsetX])
        shadow.xScale = 0.58 + contact * 0.42
        shadow.yScale = 0.72 + contact * 0.28
        shadow.alpha = min(1, contact)

        // Sticking out a tongue requires a small opening even if microphone input
        // currently asks for a closed jaw.
        let opening = max(jaw, tongueOut * 0.42)
        mouthPivot.yScale = 0.045 + opening * 0.955
        mouthPivot.xScale = 1 + smile * 0.065 - opening * 0.035
        mouthPivot.alpha = min(1, opening * 8)

        // Reflecting a construction-time curve supplies both smile and frown.
        // A small residual scale keeps the closed seam from disappearing at zero.
        smilePivot.yScale = smile >= 0
            ? max(0.12, smile)
            : min(-0.12, smile)
        smilePivot.xScale = 1 + abs(smile) * 0.025
        smilePivot.alpha = max(0, 1 - opening * 5)

        tonguePivot.position = CGPoint(
            x: signed(pose[.gazeX]) * 3,
            y: CGFloat(character.mouth.centerY) - mouthDepth * opening * 0.53
        )
        tonguePivot.xScale = 0.78 + tongueOut * 0.22
        tonguePivot.yScale = 0.08 + tongueOut * 0.92
        tonguePivot.zRotation = signed(pose[.gazeX]) * 0.06
        tonguePivot.alpha = tongueOut

        let flush = min(1, 0.23 + max(0, 1 - squash) * 1.5 + max(0, smile) * 0.23)
        cheekLeft.alpha = flush
        cheekRight.alpha = flush
        cheekLeft.yScale = 1 + max(0, smile) * 0.10
        cheekRight.yScale = cheekLeft.yScale

        eyeLeft.apply(pose: pose)
        eyeRight.apply(pose: pose)

        let b = character.brows
        let e = character.eyes
        let lift = signed(pose[.browLift])
        let angle = signed(pose[.browAngle])
        browLeft.position = CGPoint(
            x: CGFloat(e.leftCenter.x), y: CGFloat(b.centerY) + lift * 13
        )
        browRight.position = CGPoint(
            x: CGFloat(e.rightCenter.x), y: CGFloat(b.centerY) + lift * 13
        )
        browLeft.zRotation = angle * 0.42
        browRight.zRotation = -angle * 0.42
    }

    private func unit(_ value: Double) -> CGFloat {
        CGFloat(value).clamped(to: 0...1)
    }

    private func signed(_ value: Double) -> CGFloat {
        CGFloat(value).clamped(to: -1...1)
    }
}

// MARK: - Eye

/// A fixed eyeball behind a moving fabric lid. The small circular mask prevents both
/// the pupil and the lid from escaping their socket; the eyeball never squashes.
@MainActor
private final class PuppetEye {
    let node = SKNode()

    private let pupil = SKNode()
    private let lid = SKNode()
    private let lidEdge = SKNode()
    private let lashes = SKNode()
    private let closedSeam = SKNode()

    private let radius: CGFloat
    private let pupilRadius: CGFloat
    private let lidRest: CGFloat
    private let lashLength: CGFloat

    init(radius: CGFloat, character: CharacterDescriptor, side: CGFloat) {
        self.radius = radius
        pupilRadius = radius * CGFloat(character.eyes.pupilRatio)
        lidRest = CGFloat(character.eyes.lidRest)
        let surface = character.surface ?? .init()
        lashLength = CGFloat(surface.lashLength)
        let palette = character.palette
        let r = radius

        let socketRect = CGRect(
            x: -r - 7, y: -r - 7, width: 2 * r + 14, height: 2 * r + 14
        )
        let socket = PuppetPaint.bake(
            bounds: socketRect.insetBy(dx: -5, dy: -5)
        ) { context in
            PuppetPaint.felt(
                PuppetPaint.ellipse(socketRect),
                in: context, color: palette.fur,
                surface: surface, seed: 601
            )
            PuppetPaint.soft(
                in: context,
                rect: socketRect.insetBy(dx: 1, dy: 1).offsetBy(dx: 0, dy: 2),
                color: palette.fur.shaded(0.9), opacity: 0.7
            )
        }
        node.addChild(socket.node())

        let diskRect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
        let disk = PuppetPaint.ellipse(diskRect)

        let mask = PuppetPaint.bake(bounds: diskRect.insetBy(dx: -1, dy: -1)) {
            context in
            context.addPath(disk)
            context.setFillColor(UIColor.white.cgColor)
            context.fillPath()
        }
        let crop = SKCropNode()
        crop.maskNode = mask.node()
        crop.zPosition = 1
        node.addChild(crop)

        let white = PuppetPaint.bake(bounds: diskRect.insetBy(dx: -1, dy: -1)) {
            context in
            context.addPath(disk)
            context.clip()
            PuppetPaint.linear(
                in: context, rect: diskRect,
                colors: [
                    palette.eyeWhite.shaded(0.23),
                    palette.eyeWhite,
                    palette.eyeWhite.shaded(0.10)
                ],
                locations: [0, 0.32, 1]
            )
            PuppetPaint.soft(
                in: context,
                rect: CGRect(x: -r * 0.9, y: -r * 0.1, width: r * 1.4, height: r),
                color: ColorSpec(1, 1, 1), opacity: 0.48
            )
        }
        crop.addChild(white.node())

        let pr = pupilRadius
        let pupilRect = CGRect(x: -pr, y: -pr, width: pr * 2, height: pr * 2)
        let pupilArt = PuppetPaint.bake(
            bounds: pupilRect.insetBy(dx: -2, dy: -2)
        ) { context in
            context.addPath(PuppetPaint.ellipse(pupilRect))
            context.clip()
            PuppetPaint.linear(
                in: context, rect: pupilRect,
                colors: [palette.pupil.shaded(0.55), palette.pupil.lightened(0.16)],
                locations: [0, 1]
            )

            for (rect, alpha) in [
                (CGRect(x: -pr * 0.46, y: pr * 0.16,
                        width: pr * 0.48, height: pr * 0.48), CGFloat(0.95)),
                (CGRect(x: pr * 0.22, y: -pr * 0.38,
                        width: pr * 0.21, height: pr * 0.21), CGFloat(0.68))
            ] {
                context.addEllipse(in: rect)
                context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
                context.fillPath()
            }
        }
        pupil.addChild(pupilArt.node())
        pupil.zPosition = 1
        crop.addChild(pupil)

        let lidRect = CGRect(x: -r - 4, y: -2 * r - 8, width: 2 * r + 8, height: 2 * r + 8)
        let lidPath = CGPath(rect: lidRect, transform: nil)
        let lidArt = PuppetPaint.bake(bounds: lidRect) { context in
            PuppetPaint.felt(
                lidPath, in: context, color: palette.fur,
                surface: surface, seed: 602
            )
        }
        lid.addChild(lidArt.node())
        lid.position.y = r + 4
        lid.zPosition = 3
        crop.addChild(lid)

        // The edge moves independently of the lid's scale, preserving its thickness.
        let edgeRect = CGRect(x: -r - 3, y: -3, width: 2 * r + 6, height: 7)
        let edge = PuppetPaint.bake(bounds: edgeRect) { context in
            PuppetPaint.linear(
                in: context, rect: edgeRect,
                colors: [
                    palette.fur.lightened(0.14),
                    palette.fur.shaded(0.25),
                    palette.fur.shaded(0.66)
                ],
                locations: [0, 0.48, 1]
            )
        }
        lidEdge.addChild(edge.node())
        lidEdge.zPosition = 4
        crop.addChild(lidEdge)

        // Two of the four characters have no lashes. Baking a transparent texture for
        // them and adding an empty node is work and memory for nothing.
        if surface.lashLength > 0 {
        let lashArt = PuppetPaint.bake(
            bounds: CGRect(x: -r - 3, y: -2, width: 2 * r + 6, height: 18)
        ) { context in
            let length = CGFloat(surface.lashLength)
            let path = CGMutablePath()
            for fraction: CGFloat in [0.40, 0.62, 0.79] {
                let x = side * r * fraction
                path.move(to: CGPoint(x: x, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: x + side * length * 0.38, y: length),
                    control: CGPoint(x: x + side * length * 0.12, y: length * 0.60)
                )
            }
            PuppetPaint.stroke(
                path, in: context, color: palette.fur.shaded(0.74), width: 1.8
            )
        }
        lashes.addChild(lashArt.node())
        lashes.zPosition = 5
        crop.addChild(lashes)
        }

        let lower = CGMutablePath()
        lower.addArc(
            center: .zero, radius: r + 2,
            startAngle: .pi * 1.13, endAngle: .pi * 1.87,
            clockwise: false
        )
        let lowerArt = PuppetPaint.bake(bounds: socketRect) { context in
            PuppetPaint.stroke(
                lower, in: context, color: palette.fur.shaded(0.3), width: 4
            )
            var transform = CGAffineTransform(translationX: 0, y: -1.3)
            if let bounce = lower.copy(using: &transform) {
                PuppetPaint.stroke(
                    bounce, in: context,
                    color: palette.fur.lightened(0.28), width: 1.3
                )
            }
        }
        let lowerNode = lowerArt.node()
        lowerNode.zPosition = 2
        node.addChild(lowerNode)

        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: -r * 0.78, y: 0))
        seamPath.addQuadCurve(
            to: CGPoint(x: r * 0.78, y: 0),
            control: CGPoint(x: 0, y: -r * 0.20)
        )
        let seam = PuppetPaint.bake(
            bounds: CGRect(x: -r, y: -r * 0.2 - 3, width: r * 2, height: r * 0.2 + 6)
        ) { context in
            PuppetPaint.stroke(
                seamPath, in: context, color: palette.fur.shaded(0.60), width: 2.4
            )
        }
        closedSeam.addChild(seam.node())
        closedSeam.zPosition = 6
        crop.addChild(closedSeam)
    }

    func apply(pose: PuppetPose) {
        let blink = CGFloat(pose[.blink]).clamped(to: 0...1)
        let gx = CGFloat(pose[.gazeX]).clamped(to: -1...1)
        let gy = CGFloat(pose[.gazeY]).clamped(to: -1...1)

        // Normalising the diagonal keeps the entire pupil inside the eyeball.
        let travel = max(0, radius - pupilRadius - 2) * 0.84
        let magnitude = max(1, hypot(gx, gy))
        pupil.position = CGPoint(
            x: gx / magnitude * travel,
            y: gy / magnitude * travel * 0.86
        )

        let rest = (lidRest - gy * 0.055).clamped(to: 0...0.75)
        let closure = rest + (1 - rest) * blink
        let coverage = 0.025 + closure * 0.975
        lid.yScale = coverage

        let edgeY = radius + 4 - (2 * radius + 8) * coverage
        lidEdge.position.y = edgeY
        lashes.position.y = edgeY + 1
        lashes.alpha = lashLength > 0 ? 1 - blink : 0

        closedSeam.alpha = ((blink - 0.87) / 0.13).clamped(to: 0...1)
    }
}

// MARK: - Runtime artwork

/// A texture remembers its drawing origin so pivots stay in design coordinates,
/// including asymmetric parts such as the downward-opening mouth.
@MainActor
private struct PuppetStamp {
    let texture: SKTexture
    let bounds: CGRect

    func node() -> SKSpriteNode {
        let result = SKSpriteNode(texture: texture, color: .white, size: bounds.size)
        result.position = CGPoint(x: bounds.midX, y: bounds.midY)
        return result
    }
}

@MainActor
private enum PuppetPaint {

    // MARK: Stamp cache
    //
    // Baking a whole puppet was measured at ~100 ms on the Simulator, and it happens
    // synchronously on the main thread from a button tap in the cast sheet — once per
    // attached renderer, so twice in Big Screen mode and twice again for a duet. Nothing
    // about a character's stamps changes at runtime, so flipping back to one you have
    // already seen should cost nothing.
    //
    // Keyed by character id, source line and bounds. `#line` is what makes this work
    // without touching twenty-one call sites: it is unique per call site, stable across
    // builds, and cannot collide between two different drawings.

    private static var cache: [String: PuppetStamp] = [:]
    /// Least-recently-built first. Two is the working set (a duet); three leaves room to
    /// flip to a third character and back without paying for it.
    private static var recentCharacters: [String] = []
    private static let maximumCachedCharacters = 3
    private static var currentCharacterID = ""

    /// Called once at the top of `PuppetRig.init`, before anything is baked.
    static func beginCharacter(_ id: String) {
        currentCharacterID = id
        recentCharacters.removeAll { $0 == id }
        recentCharacters.append(id)
        while recentCharacters.count > maximumCachedCharacters {
            let evicted = recentCharacters.removeFirst()
            let prefix = evicted + "#"
            cache = cache.filter { !$0.key.hasPrefix(prefix) }
        }
    }

    static func bake(
        bounds: CGRect,
        line: Int = #line,
        draw: (CGContext) -> Void
    ) -> PuppetStamp {
        let bounds = bounds.integral
        let key = "\(currentCharacterID)#\(line)#\(bounds)"
        if let cached = cache[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        // Fixed density avoids tripling texture dimensions on a 3× phone.
        // These parts normally display at roughly one design point per screen point.
        format.scale = 2
        format.opaque = false
        format.preferredRange = .standard

        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image {
            renderer in
            let context = renderer.cgContext
            context.translateBy(x: -bounds.minX, y: bounds.maxY)
            context.scaleBy(x: 1, y: -1)
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            draw(context)
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        let stamp = PuppetStamp(texture: texture, bounds: bounds)
        cache[key] = stamp
        return stamp
    }

    static func ellipse(_ rect: CGRect) -> CGPath {
        CGPath(ellipseIn: rect, transform: nil)
    }

    static func color(_ value: ColorSpec, alpha: CGFloat = 1) -> CGColor {
        UIColor(
            red: CGFloat(value.red),
            green: CGFloat(value.green),
            blue: CGFloat(value.blue),
            alpha: CGFloat(value.alpha) * alpha
        ).cgColor
    }

    static func linear(
        in context: CGContext,
        rect: CGRect,
        colors: [ColorSpec],
        locations: [CGFloat]
    ) {
        let cgColors = colors.map { color($0) } as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: cgColors,
            locations: locations
        ) else { return }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    static func soft(
        in context: CGContext,
        rect: CGRect,
        color value: ColorSpec,
        opacity: CGFloat
    ) {
        guard rect.width > 0, rect.height > 0 else { return }

        let colors = [
            color(value, alpha: opacity),
            color(value, alpha: opacity * 0.62),
            color(value, alpha: opacity * 0.18),
            color(value, alpha: 0)
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.35, 0.70, 1]
        ) else { return }

        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: rect.width / 2, y: rect.height / 2)
        context.drawRadialGradient(
            gradient,
            startCenter: .zero, startRadius: 0,
            endCenter: .zero, endRadius: 1,
            options: []
        )
        context.restoreGState()
    }

    static func stroke(
        _ path: CGPath,
        in context: CGContext,
        color value: ColorSpec,
        width: CGFloat,
        alpha: CGFloat = 1
    ) {
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(color(value, alpha: alpha))
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        context.restoreGState()
    }

    /// `contour` draws a crisp outline around the finished shape.
    ///
    /// The soft nested strokes below give felt its fuzzy halo, but at 0.18 alpha they
    /// are not a silhouette — without a real contour the head, torso and arms are all
    /// one fur colour and merge into a single blob at arm's length. Pass nil only for
    /// parts that sit *inside* another shape, where an outline would read as a crack.
    static func felt(
        _ path: CGPath,
        in context: CGContext,
        color base: ColorSpec,
        surface: CharacterDescriptor.Surface,
        seed: UInt64,
        fiberAmount: CGFloat = 1,
        contour: ColorSpec? = nil,
        contourWidth: CGFloat = 3
    ) {
        let bounds = path.boundingBoxOfPath

        // Nested translucent strokes give a short fuzzy falloff, already rasterised.
        // There is no live blur or SpriteKit shape tessellation behind these edges.
        for (width, alpha) in [
            (CGFloat(7), CGFloat(0.035)),
            (CGFloat(4), CGFloat(0.075)),
            (CGFloat(1.5), CGFloat(0.18))
        ] {
            stroke(
                path, in: context, color: base.shaded(0.6),
                width: width, alpha: alpha
            )
        }

        context.saveGState()
        context.addPath(path)
        context.clip()

        linear(
            in: context, rect: bounds,
            colors: [
                base.lightened(0.27),
                base.lightened(0.06),
                base.shaded(0.17),
                base.shaded(0.29)
            ],
            locations: [0, 0.30, 0.74, 1]
        )

        // A broad front light gives the middle volume without a plastic specular spot.
        soft(
            in: context,
            rect: CGRect(
                x: bounds.minX - bounds.width * 0.10,
                y: bounds.minY + bounds.height * 0.16,
                width: bounds.width * 1.05,
                height: bounds.height * 1.12
            ),
            color: ColorSpec(1, 0.94, 0.81),
            opacity: 0.13
        )

        let bounce = ColorSpec(
            min(1, base.red * 0.8 + 0.20),
            min(1, base.green * 0.8 + 0.13),
            min(1, base.blue * 0.8 + 0.08)
        )
        soft(
            in: context,
            rect: CGRect(
                x: bounds.minX,
                y: bounds.minY - bounds.height * 0.17,
                width: bounds.width,
                height: bounds.height * 0.39
            ),
            color: bounce, opacity: 0.36
        )

        // Offset contours distribute light around the boundary instead of imposing
        // the same dark stroke on the lit crown and the underside.
        var down = CGAffineTransform(translationX: 0.6, y: -1.5)
        if let highlight = path.copy(using: &down) {
            stroke(
                highlight, in: context, color: base.lightened(0.60),
                width: 2, alpha: 0.32
            )
        }
        var up = CGAffineTransform(translationX: -0.4, y: 1.5)
        if let underside = path.copy(using: &up) {
            stroke(
                underside, in: context, color: base.shaded(0.60),
                width: 2.5, alpha: 0.30
            )
        }

        fibers(
            in: context, bounds: bounds, surface: surface,
            seed: seed, amount: fiberAmount
        )
        context.restoreGState()

        // Last, and outside the clip, so it reads at thumbnail size and is not eaten by
        // the gradient it is drawn over.
        if let contour {
            stroke(path, in: context, color: contour, width: contourWidth, alpha: 0.92)
        }
    }

    private static func fibers(
        in context: CGContext,
        bounds: CGRect,
        surface: CharacterDescriptor.Surface,
        seed: UInt64,
        amount: CGFloat
    ) {
        guard amount > 0 else { return }

        var noise = PuppetNoise(seed: seed)
        // One fibre per 28 square points, capped. The first version used one per 7 and
        // capped at 12,000, which was measured as roughly 87% of the ~100 ms it took to
        // build a whole puppet. At these texture sizes the extra strokes were landing on
        // top of each other: the weave reads the same, and what little density is lost
        // is bought back by stroking slightly harder below.
        let count = min(3_000, max(24, Int(bounds.width * bounds.height / 28)))
        let light = CGMutablePath()
        let dark = CGMutablePath()
        let length = CGFloat(surface.fiberLength).clamped(to: 0.4...3)
        let contrast = CGFloat(surface.fiberContrast).clamped(to: 0...0.18) * amount

        for i in 0..<count {
            let x = bounds.minX + noise.unit() * bounds.width
            let y = bounds.minY + noise.unit() * bounds.height
            let dx = (noise.unit() - 0.5) * length
            let dy = length * (0.25 + noise.unit() * 0.75)
            let target = i.isMultiple(of: 2) ? light : dark
            target.move(to: CGPoint(x: x, y: y))
            target.addLine(to: CGPoint(x: x + dx, y: y + dy))
        }

        stroke(
            dark, in: context, color: ColorSpec(0.08, 0.05, 0.04),
            width: 0.7, alpha: contrast * 1.35
        )
        stroke(
            light, in: context, color: ColorSpec(1, 0.98, 0.90),
            width: 0.8, alpha: contrast * 1.6
        )
    }
}

@MainActor
private struct PuppetNoise {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func unit() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 40) / CGFloat(1 << 24)
    }
}
