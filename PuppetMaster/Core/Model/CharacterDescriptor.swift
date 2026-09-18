import Foundation

/// A colour, expressed without importing a UI framework.
///
/// `Core/` stays pure Swift, so characters cannot be described in `UIColor`. The stage
/// converts these at build time.
public struct ColorSpec: Codable, Sendable, Equatable {
    public var red: Double, green: Double, blue: Double, alpha: Double

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// Darken toward black. Used to derive outline colours so a character needs one
    /// fur colour rather than two that can drift apart.
    public func shaded(_ amount: Double) -> ColorSpec {
        let k = 1 - amount.clamped(to: 0...1)
        return ColorSpec(red * k, green * k, blue * k, alpha)
    }

    public func lightened(_ amount: Double) -> ColorSpec {
        let k = amount.clamped(to: 0...1)
        return ColorSpec(red + (1 - red) * k, green + (1 - green) * k, blue + (1 - blue) * k, alpha)
    }
}

/// A complete character, as data.
///
/// This is the type that makes "characters are content, not code" true: the stage
/// builds an identical node hierarchy for every character and only the numbers differ.
/// Adding a cast member is one value in `CharacterLibrary` — no new views, no new
/// actions, no renderer changes.
///
/// It is `Codable` throughout so it can move to per-character JSON (and therefore to
/// downloadable character packs) without the runtime changing.
public struct CharacterDescriptor: Identifiable, Sendable, Codable, Equatable {

    public var id: String
    public var name: String
    /// One line, shown in the character picker. Sets expectations for the personality.
    public var tagline: String

    public var palette: Palette
    public var body: Body
    public var head: Head
    public var eyes: Eyes
    public var mouth: Mouth
    public var brows: Brows
    public var arms: Arms
    public var crest: Crest
    public var personality: Personality
    /// How the character's surface is lit and finished — the difference between a filled
    /// path and something that looks made of felt. Optional so a character encoded
    /// before this existed still decodes, and falls back to a sensible material.
    public var surface: Surface? = nil

    // MARK: Parts

    /// Material and the small facial features that carry most of the appeal.
    public struct Surface: Sendable, Codable, Equatable {
        /// How strongly the fibre texture reads. Too high and it stops being fabric and
        /// starts being noise.
        public var fiberContrast: Double
        public var fiberLength: Double
        public var muzzleWidth: Double
        public var muzzleHeight: Double
        /// Zero for characters that should not have lashes — it is a strong signal and
        /// only some of the cast want it.
        public var lashLength: Double
        public var blush: ColorSpec

        public init(fiberContrast: Double = 0.075,
                    fiberLength: Double = 1.6,
                    muzzleWidth: Double = 40,
                    muzzleHeight: Double = 20,
                    lashLength: Double = 0,
                    blush: ColorSpec = ColorSpec(0.92, 0.39, 0.36)) {
            self.fiberContrast = fiberContrast
            self.fiberLength = fiberLength
            self.muzzleWidth = muzzleWidth
            self.muzzleHeight = muzzleHeight
            self.lashLength = lashLength
            self.blush = blush
        }
    }

    public struct Palette: Sendable, Codable, Equatable {
        public var fur: ColorSpec
        public var belly: ColorSpec
        public var accent: ColorSpec         // crest, and any highlight
        public var eyeWhite: ColorSpec
        public var pupil: ColorSpec
        public var mouthInterior: ColorSpec
        public var tongue: ColorSpec

        /// Outlines are derived, not authored, so they can never drift from the fur.
        public var outline: ColorSpec { fur.shaded(0.32) }

        public init(fur: ColorSpec,
                    belly: ColorSpec? = nil,
                    accent: ColorSpec,
                    eyeWhite: ColorSpec = ColorSpec(1.00, 0.97, 0.91),
                    pupil: ColorSpec = ColorSpec(0.16, 0.13, 0.11),
                    mouthInterior: ColorSpec = ColorSpec(0.42, 0.15, 0.21),
                    tongue: ColorSpec = ColorSpec(0.91, 0.45, 0.50)) {
            self.fur = fur
            self.belly = belly ?? fur.lightened(0.45)
            self.accent = accent
            self.eyeWhite = eyeWhite
            self.pupil = pupil
            self.mouthInterior = mouthInterior
            self.tongue = tongue
        }
    }

    /// Silhouette. Measured from the floor contact point upward, so `bodyRotation`
    /// topples the character around its base.
    public struct Body: Sendable, Codable, Equatable {
        public var height: Double = 208
        public var waistHalfWidth: Double = 104   // widest point
        public var shoulderHalfWidth: Double = 66
        public var baseHalfWidth: Double = 82
        public var bellyWidth: Double = 104
        public var bellyHeight: Double = 140
        public var bellyCenterY: Double = 96

        public init(height: Double = 208, waistHalfWidth: Double = 104,
                    shoulderHalfWidth: Double = 66, baseHalfWidth: Double = 82,
                    bellyWidth: Double = 104, bellyHeight: Double = 140,
                    bellyCenterY: Double = 96) {
            self.height = height; self.waistHalfWidth = waistHalfWidth
            self.shoulderHalfWidth = shoulderHalfWidth; self.baseHalfWidth = baseHalfWidth
            self.bellyWidth = bellyWidth; self.bellyHeight = bellyHeight
            self.bellyCenterY = bellyCenterY
        }
    }

    public struct Head: Sendable, Codable, Equatable {
        public var halfWidth: Double = 102
        public var halfHeight: Double = 92
        public var centerY: Double = 248

        public init(halfWidth: Double = 102, halfHeight: Double = 92, centerY: Double = 248) {
            self.halfWidth = halfWidth; self.halfHeight = halfHeight; self.centerY = centerY
        }
    }

    public struct Eyes: Sendable, Codable, Equatable {
        public var leftRadius: Double = 34
        public var rightRadius: Double = 23
        public var leftCenter: Point = Point(-46, 26)
        public var rightCenter: Point = Point(48, 20)
        public var pupilRatio: Double = 0.46
        /// How far the lid sits closed at rest. Heavy lids read as sleepy or deadpan
        /// without any change to the blink logic.
        public var lidRest: Double = 0

        public init(leftRadius: Double = 34, rightRadius: Double = 23,
                    leftCenter: Point = Point(-46, 26), rightCenter: Point = Point(48, 20),
                    pupilRatio: Double = 0.46, lidRest: Double = 0) {
            self.leftRadius = leftRadius; self.rightRadius = rightRadius
            self.leftCenter = leftCenter; self.rightCenter = rightCenter
            self.pupilRatio = pupilRatio; self.lidRest = lidRest
        }
    }

    public struct Mouth: Sendable, Codable, Equatable {
        public var halfWidth: Double = 62
        public var depth: Double = 92        // how far the jaw drops when fully open
        public var centerY: Double = -22
        public var lipThickness: Double = 20

        public init(halfWidth: Double = 62, depth: Double = 92,
                    centerY: Double = -22, lipThickness: Double = 20) {
            self.halfWidth = halfWidth; self.depth = depth
            self.centerY = centerY; self.lipThickness = lipThickness
        }
    }

    public struct Brows: Sendable, Codable, Equatable {
        public var leftWidth: Double = 66
        public var rightWidth: Double = 48
        public var thickness: Double = 12
        public var centerY: Double = 74

        public init(leftWidth: Double = 66, rightWidth: Double = 48,
                    thickness: Double = 12, centerY: Double = 74) {
            self.leftWidth = leftWidth; self.rightWidth = rightWidth
            self.thickness = thickness; self.centerY = centerY
        }
    }

    public struct Arms: Sendable, Codable, Equatable {
        public var shoulder: Point = Point(72, 172)   // mirrored for the left arm
        public var length: Double = 96
        public var thickness: Double = 23

        public init(shoulder: Point = Point(72, 172), length: Double = 96, thickness: Double = 23) {
            self.shoulder = shoulder; self.length = length; self.thickness = thickness
        }
    }

    /// What sits on top of the head. The cheapest way to make two characters built from
    /// the same rig read as different species.
    public struct Crest: Sendable, Codable, Equatable {
        public enum Kind: String, Sendable, Codable { case tuft, ears, antenna, spikes, none }
        public var kind: Kind = .tuft
        public var size: Double = 1.0
        public var offsetY: Double = 74
        /// Multiplies the lag spring. Long ears should swing more than a stiff tuft.
        public var swing: Double = 1.0

        public init(kind: Kind = .tuft, size: Double = 1.0,
                    offsetY: Double = 74, swing: Double = 1.0) {
            self.kind = kind; self.size = size; self.offsetY = offsetY; self.swing = swing
        }
    }

    /// How the character behaves when nobody is touching anything.
    ///
    /// This is doing more work than the shapes are. A fast, shallow breather that blinks
    /// constantly reads as anxious; a slow one with heavy lids reads as bored — from the
    /// same geometry. Personality lives in the timing.
    public struct Personality: Sendable, Codable, Equatable {
        public var breathPeriod: Double = 3.4
        public var breathAmount: Double = 1.0
        public var blinkInterval: ClosedRangeSpec = ClosedRangeSpec(2.0, 6.5)
        public var blinkSpeed: Double = 1.0
        public var swayAmount: Double = 1.0
        public var gazeWander: Double = 1.0
        public var headTiltAmount: Double = 1.0
        /// Chance, per blink, of a second one right after.
        public var doubleBlinkChance: Double = 0.25
        /// Multiplies every sound the character makes. A small creature should squeak
        /// and a large one should rumble, out of the same synthesised bank.
        public var voicePitch: Double = 1.0

        public init(breathPeriod: Double = 3.4, breathAmount: Double = 1.0,
                    blinkInterval: ClosedRangeSpec = ClosedRangeSpec(2.0, 6.5),
                    blinkSpeed: Double = 1.0, swayAmount: Double = 1.0,
                    gazeWander: Double = 1.0, headTiltAmount: Double = 1.0,
                    doubleBlinkChance: Double = 0.25,
                    voicePitch: Double = 1.0) {
            self.breathPeriod = breathPeriod; self.breathAmount = breathAmount
            self.blinkInterval = blinkInterval; self.blinkSpeed = blinkSpeed
            self.swayAmount = swayAmount; self.gazeWander = gazeWander
            self.headTiltAmount = headTiltAmount; self.doubleBlinkChance = doubleBlinkChance
            self.voicePitch = voicePitch
        }
    }
}

/// A 2D point, `Codable` and free of any graphics framework.
public struct Point: Sendable, Codable, Equatable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

/// `ClosedRange` is not `Codable` for our purposes here; this is.
public struct ClosedRangeSpec: Sendable, Codable, Equatable {
    public var lower: Double, upper: Double
    public init(_ lower: Double, _ upper: Double) { self.lower = lower; self.upper = upper }
    public var range: ClosedRange<Double> { lower...max(lower, upper) }
}
