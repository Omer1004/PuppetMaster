// Renders the App Store icon.
//
//     swift scripts/render-app-icon.swift \
//       PuppetMaster/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// A macOS command-line script, deliberately outside the app target: it imports AppKit
// and would not compile for iOS. `scripts/` is not part of the synchronized source
// group, so Xcode never sees it.
//
// The icon is code rather than a PNG someone drew once, for the same reason the cast is
// data: the palette here is the real palette from Core/Content/CharacterLibrary.swift,
// so when Moppet's colours change the icon can follow in one command instead of a round
// trip to an illustrator. The PRNG is seeded, so re-running this produces a
// byte-identical file and the diff stays empty unless something actually changed.
//
// Constraints the App Store enforces, all of which this satisfies: 1024x1024, opaque,
// no alpha channel, no rounded corners (iOS applies the mask), no text.
//
// First draft written by GPT-6 via the Codex CLI; the backdrop warmth and the head
// position were tuned by hand afterwards.

import Foundation
import CoreGraphics
import ImageIO
import AppKit

let size = 1024
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

struct Ink {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat

    func color(_ alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: sRGB, components: [r, g, b, alpha])!
    }

    func mixed(with other: Ink, amount: CGFloat) -> Ink {
        Ink(
            r: r + (other.r - r) * amount,
            g: g + (other.g - g) * amount,
            b: b + (other.b - b) * amount
        )
    }
}

let fur = Ink(r: 0.13, g: 0.52, b: 0.53)
let muzzle = Ink(r: 0.55, g: 0.85, b: 0.80)
let accent = Ink(r: 0.98, g: 0.54, b: 0.24)
let blush = Ink(r: 0.94, g: 0.43, b: 0.35)
let maroon = Ink(r: 0.18, g: 0.095, b: 0.13)
let cream = Ink(r: 0.98, g: 0.94, b: 0.81)
let white = Ink(r: 1, g: 1, b: 1)
let black = Ink(r: 0, g: 0, b: 0)

// SplitMix64: fixed seed and fixed iteration counts make texture reproducible.
struct SeededRandom {
    var state: UInt64 = 0x5075707065742026

    mutating func unit() -> CGFloat {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return CGFloat(Double(z >> 11) / 9007199254740992.0)
    }

    mutating func range(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        low + (high - low) * unit()
    }
}

func gradient(_ colors: [CGColor], _ stops: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: stops)!
}

func radial(
    _ context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    colors: [CGColor],
    stops: [CGFloat] = [0, 1]
) {
    context.drawRadialGradient(
        gradient(colors, stops),
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

func fill(_ context: CGContext, _ path: CGPath, _ ink: Ink, alpha: CGFloat = 1) {
    context.addPath(path)
    context.setFillColor(ink.color(alpha))
    context.fillPath()
}

func stroke(
    _ context: CGContext,
    _ path: CGPath,
    _ ink: Ink,
    width: CGFloat,
    alpha: CGFloat = 1
) {
    context.addPath(path)
    context.setStrokeColor(ink.color(alpha))
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
}

func clipped(_ context: CGContext, to path: CGPath, draw: () -> Void) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    draw()
    context.restoreGState()
}

func headPath() -> CGPath {
    // Broad cushion cheeks, slightly uneven crown, and a soft flattened chin.
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 505, y: 255))
    p.addCurve(to: CGPoint(x: 728, y: 276),
               control1: CGPoint(x: 591, y: 238),
               control2: CGPoint(x: 675, y: 246))
    p.addCurve(to: CGPoint(x: 859, y: 398),
               control1: CGPoint(x: 793, y: 297),
               control2: CGPoint(x: 841, y: 341))
    p.addCurve(to: CGPoint(x: 892, y: 598),
               control1: CGPoint(x: 883, y: 457),
               control2: CGPoint(x: 879, y: 514))
    p.addCurve(to: CGPoint(x: 814, y: 795),
               control1: CGPoint(x: 903, y: 680),
               control2: CGPoint(x: 871, y: 754))
    p.addCurve(to: CGPoint(x: 607, y: 875),
               control1: CGPoint(x: 758, y: 845),
               control2: CGPoint(x: 679, y: 872))
    p.addCurve(to: CGPoint(x: 377, y: 869),
               control1: CGPoint(x: 528, y: 889),
               control2: CGPoint(x: 450, y: 883))
    p.addCurve(to: CGPoint(x: 194, y: 767),
               control1: CGPoint(x: 293, y: 857),
               control2: CGPoint(x: 226, y: 824))
    p.addCurve(to: CGPoint(x: 141, y: 566),
               control1: CGPoint(x: 151, y: 714),
               control2: CGPoint(x: 137, y: 637))
    p.addCurve(to: CGPoint(x: 190, y: 374),
               control1: CGPoint(x: 143, y: 489),
               control2: CGPoint(x: 152, y: 424))
    p.addCurve(to: CGPoint(x: 332, y: 272),
               control1: CGPoint(x: 223, y: 316),
               control2: CGPoint(x: 274, y: 287))
    p.addCurve(to: CGPoint(x: 505, y: 255),
               control1: CGPoint(x: 389, y: 248),
               control2: CGPoint(x: 447, y: 250))
    p.closeSubpath()
    return p
}

func fibers(
    _ context: CGContext,
    bounds: CGRect,
    count: Int,
    base: Ink,
    seed: UInt64,
    length: CGFloat = 4,
    opacity: CGFloat = 1
) {
    var random = SeededRandom(state: seed)
    context.setLineCap(.round)

    for i in 0..<count {
        let x = random.range(bounds.minX, bounds.maxX)
        let y = random.range(bounds.minY, bounds.maxY)
        let lean = (x - 512) / 450

        // Crossed, uneven fibers suggest tangled felt rather than a brushed surface.
        let angle = CGFloat.pi / 2 - lean * 0.65
            + random.range(-CGFloat.pi, CGFloat.pi)
        let span = random.range(length * 0.35, length * 2.1)
        let bow = random.range(-0.22, 0.22) * span
        let light = i % 2 == 0
        let ink = base.mixed(
            with: light ? cream : maroon,
            amount: light ? 0.48 : 0.48
        )

        let dx = cos(angle) * span
        let dy = sin(angle) * span

        context.setStrokeColor(ink.color(random.range(0.14, 0.36) * opacity))
        context.setLineWidth(random.range(0.55, 1.25))
        context.move(to: CGPoint(x: x, y: y))
        context.addQuadCurve(
            to: CGPoint(x: x + dx, y: y + dy),
            control: CGPoint(
                x: x + dx * 0.5 - sin(angle) * bow,
                y: y + dy * 0.5 + cos(angle) * bow
            )
        )
        context.strokePath()
    }
}

func drawBackdrop(_ context: CGContext) {
    radial(
        context,
        center: CGPoint(x: 480, y: 418),
        radius: 755,
        colors: [
            Ink(r: 1.00, g: 0.81, b: 0.59).color(),
            Ink(r: 0.98, g: 0.68, b: 0.43).color(),
            Ink(r: 0.74, g: 0.35, b: 0.22).color(),
            Ink(r: 0.33, g: 0.13, b: 0.16).color()
        ],
        stops: [0, 0.36, 0.70, 1]
    )

    // Transparent through most of the field, with a slight falloff at the corners.
    radial(
        context,
        center: CGPoint(x: 512, y: 512),
        radius: 725,
        colors: [
            maroon.color(0),
            maroon.color(0),
            maroon.color(0.13)
        ],
        stops: [0, 0.70, 1]
    )

    // A diffuse stage shadow follows the raised, enlarged head.
    context.saveGState()
    context.translateBy(x: 536, y: 865)
    context.scaleBy(x: 1, y: 0.25)
    radial(context, center: .zero, radius: 400,
           colors: [maroon.color(0.24), maroon.color(0)])
    context.restoreGState()
}

func frond(base: CGPoint, tip: CGPoint, bend: CGFloat, width: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: base.x - width * 0.5, y: base.y))
    p.addCurve(to: tip,
               control1: CGPoint(x: base.x - width + bend, y: base.y - 78),
               control2: CGPoint(x: tip.x - 34, y: tip.y - 18))
    p.addCurve(to: CGPoint(x: base.x + width * 0.5, y: base.y + 4),
               control1: CGPoint(x: tip.x + 43, y: tip.y + 8),
               control2: CGPoint(x: base.x + width + bend, y: base.y - 65))
    p.closeSubpath()
    return p
}

func drawTuft(_ context: CGContext) {
    let fronds: [CGPath] = [
        frond(base: CGPoint(x: 468, y: 293), tip: CGPoint(x: 384, y: 185), bend: -27, width: 67),
        frond(base: CGPoint(x: 522, y: 285), tip: CGPoint(x: 505, y: 131), bend: -17, width: 78),
        frond(base: CGPoint(x: 568, y: 295), tip: CGPoint(x: 633, y: 176), bend: 27, width: 64)
    ]

    for (index, path) in fronds.enumerated() {
        fill(context, path, accent)
        clipped(context, to: path) {
            radial(context, center: CGPoint(x: 459, y: 162), radius: 194,
                   colors: [cream.color(0.30), cream.color(0)])
            fibers(context, bounds: CGRect(x: 330, y: 115, width: 350, height: 210),
                   count: 6500, base: accent, seed: UInt64(110 + index),
                   length: 3.4)
        }
        stroke(context, path, accent.mixed(with: maroon, amount: 0.43),
               width: 3, alpha: 0.65)
    }
}

func drawHead(_ context: CGContext, path: CGPath) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 12, height: -20),
                      blur: 31, color: maroon.color(0.35))
    fill(context, path, fur)
    context.restoreGState()

    clipped(context, to: path) {
        radial(context, center: CGPoint(x: 299, y: 325), radius: 620,
               colors: [muzzle.color(0.36), muzzle.color(0)])

        radial(context, center: CGPoint(x: 792, y: 828), radius: 510,
               colors: [maroon.color(0.27), maroon.color(0)])

        // A broad, faint warm rim; the face remains matte.
        context.saveGState()
        context.addRect(CGRect(x: 620, y: 525, width: 320, height: 390))
        context.clip()
        context.setShadow(offset: .zero, blur: 18, color: accent.color(0.35))
        stroke(context, path, accent, width: 18, alpha: 0.18)
        context.restoreGState()

        fibers(context, bounds: CGRect(x: 135, y: 238, width: 765, height: 655),
               count: 155000, base: fur, seed: 0xF311)
    }

    stroke(context, path, fur.mixed(with: maroon, amount: 0.59), width: 6)

    // Sparse short edge hairs soften the hand-cut outline without losing it.
    clipped(context, to: path) {
        var random = SeededRandom(state: 0xED63)
        for _ in 0..<1200 {
            let x = random.range(140, 895)
            let y = random.range(250, 883)
            let point = CGPoint(x: x, y: y)
            guard path.contains(point) else { continue }
            let dx = (x - 514) / 375
            let dy = (y - 562) / 315
            let end = CGPoint(x: x + dx * 7, y: y + dy * 7)
            if !path.contains(end) {
                context.setStrokeColor(muzzle.color(0.22))
                context.setLineWidth(0.85)
                context.move(to: point)
                context.addLine(to: end)
                context.strokePath()
            }
        }
    }
}

func drawEye(_ context: CGContext, center: CGPoint, radius: CGFloat, seed: UInt64) {
    let bounds = CGRect(x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2)
    let disc = CGPath(ellipseIn: bounds, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 3, height: -6),
                      blur: 8, color: maroon.color(0.30))
    fill(context, disc, cream)
    context.restoreGState()

    stroke(context, disc, cream.mixed(with: maroon, amount: 0.30), width: 3)
    clipped(context, to: disc) {
        fibers(context, bounds: bounds, count: 3200, base: cream,
               seed: seed, length: 1.8, opacity: 0.40)
    }

    // Large dark button centers and two deliberately unequal light reflections.
    let pupilCenter = CGPoint(x: center.x + 5, y: center.y + 9)
    let pupilRadius = radius * 0.46
    context.setFillColor(maroon.color())
    context.fillEllipse(in: CGRect(
        x: pupilCenter.x - pupilRadius, y: pupilCenter.y - pupilRadius,
        width: pupilRadius * 2, height: pupilRadius * 2
    ))

    context.setFillColor(white.color(0.97))
    context.fillEllipse(in: CGRect(
        x: pupilCenter.x - pupilRadius * 0.57,
        y: pupilCenter.y - pupilRadius * 0.65,
        width: pupilRadius * 0.53, height: pupilRadius * 0.53
    ))

    context.setFillColor(muzzle.color(0.43))
    context.fillEllipse(in: CGRect(
        x: pupilCenter.x + pupilRadius * 0.22,
        y: pupilCenter.y + pupilRadius * 0.25,
        width: pupilRadius * 0.25, height: pupilRadius * 0.25
    ))
}

func drawMuzzle(_ context: CGContext) {
    let patch = CGMutablePath()
    patch.move(to: CGPoint(x: 302, y: 560))
    patch.addCurve(to: CGPoint(x: 520, y: 540),
                   control1: CGPoint(x: 361, y: 527), control2: CGPoint(x: 457, y: 544))
    patch.addCurve(to: CGPoint(x: 735, y: 571),
                   control1: CGPoint(x: 611, y: 531), control2: CGPoint(x: 696, y: 542))
    patch.addCurve(to: CGPoint(x: 724, y: 730),
                   control1: CGPoint(x: 788, y: 611), control2: CGPoint(x: 765, y: 687))
    patch.addCurve(to: CGPoint(x: 513, y: 821),
                   control1: CGPoint(x: 679, y: 792), control2: CGPoint(x: 595, y: 825))
    patch.addCurve(to: CGPoint(x: 302, y: 727),
                   control1: CGPoint(x: 414, y: 825), control2: CGPoint(x: 342, y: 786))
    patch.addCurve(to: CGPoint(x: 302, y: 560),
                   control1: CGPoint(x: 256, y: 670), control2: CGPoint(x: 248, y: 594))
    patch.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -3),
                      blur: 9, color: maroon.color(0.15))
    fill(context, patch, muzzle)
    context.restoreGState()

    clipped(context, to: patch) {
        radial(context, center: CGPoint(x: 374, y: 565), radius: 355,
               colors: [cream.color(0.22), cream.color(0)])
        fibers(context, bounds: CGRect(x: 260, y: 530, width: 510, height: 300),
               count: 47000, base: muzzle, seed: 0xB311, length: 3.5)

        // One inset running stitch follows only the lower edge of the felt patch.
        let seam = CGMutablePath()
        seam.move(to: CGPoint(x: 285, y: 659))
        seam.addCurve(to: CGPoint(x: 312, y: 721),
                      control1: CGPoint(x: 290, y: 684),
                      control2: CGPoint(x: 300, y: 706))
        seam.addCurve(to: CGPoint(x: 513, y: 808),
                      control1: CGPoint(x: 351, y: 778),
                      control2: CGPoint(x: 420, y: 812))
        seam.addCurve(to: CGPoint(x: 714, y: 723),
                      control1: CGPoint(x: 591, y: 812),
                      control2: CGPoint(x: 671, y: 780))
        seam.addCurve(to: CGPoint(x: 745, y: 659),
                      control1: CGPoint(x: 730, y: 704),
                      control2: CGPoint(x: 741, y: 681))

        context.saveGState()
        context.setLineDash(phase: 2, lengths: [4.5, 6.5])
        stroke(context, seam, muzzle.mixed(with: maroon, amount: 0.65),
               width: 1.6, alpha: 0.40)
        context.restoreGState()
    }

    // A curved upper lip and a deep rounded opening make a readable delighted grin.
    let mouth = CGMutablePath()
    mouth.move(to: CGPoint(x: 321, y: 615))
    mouth.addCurve(to: CGPoint(x: 705, y: 613),
                   control1: CGPoint(x: 435, y: 645), control2: CGPoint(x: 589, y: 646))
    mouth.addCurve(to: CGPoint(x: 516, y: 784),
                   control1: CGPoint(x: 695, y: 704), control2: CGPoint(x: 620, y: 783))
    mouth.addCurve(to: CGPoint(x: 321, y: 615),
                   control1: CGPoint(x: 407, y: 791), control2: CGPoint(x: 336, y: 713))
    mouth.closeSubpath()

    fill(context, mouth, maroon)
    clipped(context, to: mouth) {
        radial(context, center: CGPoint(x: 508, y: 626), radius: 210,
               colors: [black.color(0.28), black.color(0)])

        let tongue = CGPath(
            ellipseIn: CGRect(x: 416, y: 738, width: 203, height: 94),
            transform: nil
        )
        fill(context, tongue, blush)
        clipped(context, to: tongue) {
            fibers(context, bounds: CGRect(x: 416, y: 738, width: 203, height: 94),
                   count: 4400, base: blush, seed: 0x7011, length: 3)
        }
    }
    stroke(context, mouth, maroon.mixed(with: fur, amount: 0.18), width: 5)
}

func drawBlush(_ context: CGContext, head: CGPath) {
    clipped(context, to: head) {
        for center in [CGPoint(x: 264, y: 581), CGPoint(x: 766, y: 582)] {
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.scaleBy(x: 1, y: 0.70)
            radial(context, center: .zero, radius: 76,
                   colors: [blush.color(0.23), blush.color(0.10), blush.color(0)],
                   stops: [0, 0.48, 1])
            context.restoreGState()
        }
    }
}

enum IconError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let message): return message
        }
    }
}

func renderIcon(to outputPath: String) throws {
    // RGBX storage has no alpha channel. The backdrop paints every pixel.
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: sRGB,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw IconError.message("Could not create the sRGB drawing context.")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)

    drawBackdrop(context)

    // Enlarge the entire character uniformly and lift its facial center.
    // The tuft approaches the top while the chin gains breathing room.
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.scaleBy(x: 1.08, y: 1.08)
    context.translateBy(x: -514, y: -546)

    drawTuft(context)
    let head = headPath()
    drawHead(context, path: head)
    drawMuzzle(context)
    drawBlush(context, head: head)

    // The left button is 12% larger; its higher placement adds a startled tilt.
    drawEye(context, center: CGPoint(x: 365, y: 444), radius: 91.84, seed: 0xE101)
    drawEye(context, center: CGPoint(x: 663, y: 467), radius: 82, seed: 0xE102)

    context.restoreGState()

    guard let image = context.makeImage() else {
        throw IconError.message("Could not create the rendered image.")
    }

    let url = URL(fileURLWithPath: outputPath)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil
    ) else {
        throw IconError.message("Could not open PNG destination: \(outputPath)")
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IconError.message("Failed to write PNG: \(outputPath)")
    }
}

do {
    guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 2 else {
        throw IconError.message("Usage: swift icon.swift out.png")
    }
    try renderIcon(to: CommandLine.arguments[1])
} catch {
    FileHandle.standardError.write(Data("icon.swift: \(error)\n".utf8))
    exit(1)
}
