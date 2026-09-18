import Foundation

/// The cast.
///
/// Every character here is *data* — the stage builds an identical node hierarchy for
/// all of them and only the numbers change. Adding a cast member means adding one value
/// to this file: no new views, no new actions, no renderer work. That is what makes
/// character packs a content problem rather than an engineering one.
///
/// Proportions do less work than you would expect; **timing does most of it**. Pip and
/// Bramble would still read as different creatures if they were the same shape, because
/// one breathes twice as fast and blinks four times as often.
///
/// All four are original designs. Names are working names and need trademark clearance
/// before any public use (see docs/OPEN-QUESTIONS.md Q7).
public enum CharacterLibrary {

    public static let all: [CharacterDescriptor] = [moppet, pip, bramble, thistle]

    public static let `default` = moppet

    public static func character(id: String) -> CharacterDescriptor {
        all.first { $0.id == id } ?? `default`
    }

    // MARK: Moppet — the straight man

    /// Shaggy teal sock-creature with mismatched button eyes. Steady, warm, unbothered.
    /// The mismatch means every expression reads as faintly startled, for free.
    public static let moppet = CharacterDescriptor(
        id: "moppet",
        name: "Moppet",
        tagline: "Shaggy, lopsided, always pleased to see you",
        palette: .init(
            fur: ColorSpec(0.13, 0.52, 0.53),
            belly: ColorSpec(0.55, 0.85, 0.80),
            accent: ColorSpec(0.98, 0.54, 0.24)),
        body: .init(),
        head: .init(),
        eyes: .init(),
        mouth: .init(),
        brows: .init(),
        arms: .init(),
        crest: .init(kind: .tuft, size: 1.0, offsetY: 74, swing: 1.0),
        personality: .init())

    // MARK: Pip — the excitable one

    /// Small, round and sunny, with eyes far too big for its head. Breathes fast, blinks
    /// constantly, never quite settles. Reads as delighted to exist.
    public static let pip = CharacterDescriptor(
        id: "pip",
        name: "Pip",
        tagline: "Small, round, and extremely awake",
        palette: .init(
            fur: ColorSpec(0.98, 0.78, 0.22),
            belly: ColorSpec(1.00, 0.93, 0.66),
            accent: ColorSpec(0.93, 0.35, 0.45),
            mouthInterior: ColorSpec(0.52, 0.18, 0.22)),
        body: .init(height: 156, waistHalfWidth: 92, shoulderHalfWidth: 58,
                    baseHalfWidth: 74, bellyWidth: 92, bellyHeight: 104, bellyCenterY: 72),
        head: .init(halfWidth: 98, halfHeight: 94, centerY: 196),
        eyes: .init(leftRadius: 41, rightRadius: 37,
                    leftCenter: Point(-40, 22), rightCenter: Point(44, 24),
                    pupilRatio: 0.50),
        mouth: .init(halfWidth: 46, depth: 74, centerY: -44, lipThickness: 17),
        brows: .init(leftWidth: 50, rightWidth: 46, thickness: 10, centerY: 76),
        arms: .init(shoulder: Point(64, 128), length: 74, thickness: 20),
        crest: .init(kind: .antenna, size: 1.0, offsetY: 88, swing: 1.9),
        personality: .init(breathPeriod: 2.1, breathAmount: 1.5,
                           blinkInterval: ClosedRangeSpec(0.9, 2.8), blinkSpeed: 1.5,
                           swayAmount: 1.5, gazeWander: 1.7, headTiltAmount: 1.4,
                           doubleBlinkChance: 0.45))

    // MARK: Bramble — the deadpan one

    /// Tall, lanky and lavender, with long ears that swing a beat behind everything it
    /// does and lids that never fully open. Slow breath, rare blinks. Reads as
    /// permanently unimpressed, which makes it the funniest of the four to make jump.
    public static let bramble = CharacterDescriptor(
        id: "bramble",
        name: "Bramble",
        tagline: "Tall, slow, and unimpressed by all of this",
        palette: .init(
            fur: ColorSpec(0.55, 0.45, 0.76),
            belly: ColorSpec(0.83, 0.79, 0.94),
            accent: ColorSpec(0.42, 0.72, 0.58),
            mouthInterior: ColorSpec(0.33, 0.16, 0.30)),
        body: .init(height: 262, waistHalfWidth: 74, shoulderHalfWidth: 54,
                    baseHalfWidth: 58, bellyWidth: 72, bellyHeight: 158, bellyCenterY: 118),
        head: .init(halfWidth: 84, halfHeight: 100, centerY: 306),
        eyes: .init(leftRadius: 26, rightRadius: 24,
                    leftCenter: Point(-36, 24), rightCenter: Point(38, 22),
                    pupilRatio: 0.42, lidRest: 0.40),
        mouth: .init(halfWidth: 50, depth: 88, centerY: -34, lipThickness: 16),
        brows: .init(leftWidth: 48, rightWidth: 46, thickness: 9, centerY: 66),
        arms: .init(shoulder: Point(62, 214), length: 118, thickness: 18),
        crest: .init(kind: .ears, size: 1.25, offsetY: 62, swing: 2.2),
        personality: .init(breathPeriod: 5.6, breathAmount: 0.7,
                           blinkInterval: ClosedRangeSpec(5.0, 11.0), blinkSpeed: 0.65,
                           swayAmount: 0.55, gazeWander: 0.5, headTiltAmount: 0.6,
                           doubleBlinkChance: 0.05))

    // MARK: Thistle — the troublemaker

    /// Wide, squat and mossy, with a spiky crest, a mouth that takes up half its face,
    /// and small close-set eyes. Fidgets constantly. Reads as about to do something
    /// it has been told not to.
    public static let thistle = CharacterDescriptor(
        id: "thistle",
        name: "Thistle",
        tagline: "Wide, spiky, and up to something",
        palette: .init(
            fur: ColorSpec(0.38, 0.62, 0.27),
            belly: ColorSpec(0.78, 0.88, 0.55),
            accent: ColorSpec(0.96, 0.82, 0.30),
            mouthInterior: ColorSpec(0.35, 0.17, 0.16)),
        body: .init(height: 152, waistHalfWidth: 124, shoulderHalfWidth: 92,
                    baseHalfWidth: 108, bellyWidth: 118, bellyHeight: 96, bellyCenterY: 66),
        head: .init(halfWidth: 112, halfHeight: 80, centerY: 186),
        eyes: .init(leftRadius: 25, rightRadius: 22,
                    leftCenter: Point(-30, 26), rightCenter: Point(32, 26),
                    pupilRatio: 0.48),
        mouth: .init(halfWidth: 80, depth: 76, centerY: -16, lipThickness: 18),
        brows: .init(leftWidth: 54, rightWidth: 52, thickness: 13, centerY: 60),
        arms: .init(shoulder: Point(92, 118), length: 72, thickness: 24),
        crest: .init(kind: .spikes, size: 1.1, offsetY: 62, swing: 0.6),
        personality: .init(breathPeriod: 2.8, breathAmount: 0.9,
                           blinkInterval: ClosedRangeSpec(1.4, 4.2), blinkSpeed: 1.8,
                           swayAmount: 1.8, gazeWander: 1.9, headTiltAmount: 1.6,
                           doubleBlinkChance: 0.40))
}
