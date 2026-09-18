import Foundation

/// How to divide a surface between the stage and the controls.
///
/// This is in `Core/` and takes plain numbers because the decision is worth testing and
/// the inputs are not SwiftUI's to own. `Info.plist` has advertised landscape support
/// since the prototype, but the solo layout was a fixed vertical split — which on a
/// phone in landscape left the stage 200pt tall and the controls squeezed underneath.
///
/// Size classes were the obvious alternative and are the wrong tool here: a folding
/// device's inner screen and an iPad in Split View can report the same class while
/// wanting opposite layouts. The aspect ratio is what the answer actually depends on.
public enum StageLayout: Equatable, Sendable {

    /// Stage above, controls below. `fraction` is the stage's share of the height.
    case stacked(fraction: Double)

    /// Stage beside the controls. `fraction` is the stage's share of the width.
    case sideBySide(fraction: Double)

    /// Below this aspect ratio a surface is not wide enough to be worth splitting
    /// horizontally. A near-square screen — the shape a folding device's inner display
    /// is likely to be — stays stacked, because two half-width columns would leave the
    /// puppet too small to read and the action grid down to two columns.
    public static let sideBySideThreshold: Double = 1.2

    /// Portrait gives the stage slightly more than half: the puppet is the point, and
    /// the control panel scrolls, so it loses less by being short than the stage does.
    public static let stackedFraction: Double = 0.54

    /// Landscape gives the stage slightly less than half. The controls do not scroll
    /// sideways, so their width is a hard constraint where their height is not, and a
    /// landscape stage is already wider than a portrait one at the same fraction.
    public static let sideBySideFraction: Double = 0.46

    public static func forSurface(width: Double, height: Double) -> StageLayout {
        guard width > 0, height > 0 else { return .stacked(fraction: stackedFraction) }
        guard width / height >= sideBySideThreshold else {
            return .stacked(fraction: stackedFraction)
        }
        return .sideBySide(fraction: sideBySideFraction)
    }

    public var isSideBySide: Bool {
        if case .sideBySide = self { return true }
        return false
    }

    public var fraction: Double {
        switch self {
        case .stacked(let fraction), .sideBySide(let fraction): return fraction
        }
    }
}
