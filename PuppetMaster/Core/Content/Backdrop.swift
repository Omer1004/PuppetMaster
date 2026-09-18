import Foundation

/// Where the puppet is standing.
///
/// Kept separate from the character on purpose: any cast member can perform against any
/// backdrop, and neither needs to know about the other. Like characters, these are pure
/// data — a new one is a value here, not a code change.
///
/// Backdrops are deliberately low-contrast and out of focus. Everything eye-catching on
/// screen should be the puppet; a backdrop that competes with the performer is a bad
/// backdrop.
public struct Backdrop: Identifiable, Sendable, Codable, Equatable {

    public var id: String
    public var name: String
    /// SF Symbol shown in the picker.
    public var symbol: String
    public var skyTop: ColorSpec
    public var skyBottom: ColorSpec
    public var floor: ColorSpec
    /// Scatters slow points of light across the sky.
    public var hasStars: Bool

    public init(id: String, name: String, symbol: String,
                skyTop: ColorSpec, skyBottom: ColorSpec, floor: ColorSpec,
                hasStars: Bool = false) {
        self.id = id; self.name = name; self.symbol = symbol
        self.skyTop = skyTop; self.skyBottom = skyBottom; self.floor = floor
        self.hasStars = hasStars
    }
}

public enum BackdropLibrary {

    public static let all: [Backdrop] = [sunset, meadow, midnight, showtime]
    public static let `default` = sunset

    public static func backdrop(id: String) -> Backdrop {
        all.first { $0.id == id } ?? `default`
    }

    public static let sunset = Backdrop(
        id: "sunset", name: "Sunset", symbol: "sun.horizon.fill",
        skyTop: ColorSpec(0.96, 0.68, 0.53),
        skyBottom: ColorSpec(0.99, 0.87, 0.70),
        floor: ColorSpec(0.89, 0.56, 0.44))

    public static let meadow = Backdrop(
        id: "meadow", name: "Meadow", symbol: "leaf.fill",
        skyTop: ColorSpec(0.62, 0.84, 0.93),
        skyBottom: ColorSpec(0.88, 0.95, 0.86),
        floor: ColorSpec(0.52, 0.72, 0.40))

    public static let midnight = Backdrop(
        id: "midnight", name: "Midnight", symbol: "moon.stars.fill",
        skyTop: ColorSpec(0.09, 0.11, 0.26),
        skyBottom: ColorSpec(0.26, 0.24, 0.47),
        floor: ColorSpec(0.18, 0.18, 0.34),
        hasStars: true)

    public static let showtime = Backdrop(
        id: "showtime", name: "Showtime", symbol: "theatermasks.fill",
        skyTop: ColorSpec(0.38, 0.08, 0.15),
        skyBottom: ColorSpec(0.62, 0.15, 0.22),
        floor: ColorSpec(0.30, 0.18, 0.13))
}
