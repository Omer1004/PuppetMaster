import Foundation

/// Which half of the experience a surface is showing.
///
/// The product's core idea is that the performer and the audience should not be
/// looking at the same thing. Everything about the display layer exists to serve that
/// split, on whatever hardware is available.
public enum DisplayRole: String, Sendable, CaseIterable {
    /// Stage and controls stacked on one screen. Every iPhone can do this.
    case combined
    /// Audience-facing only. No chrome, no controls, nothing but the puppet.
    case stage
    /// Performer-facing only. The instrument, never seen by the audience.
    case controls
}

/// How the app is currently spreading itself across surfaces.
public enum PresentationMode: String, CaseIterable, Identifiable, Sendable {
    /// One phone, stage above controls.
    case solo
    /// Two independent surfaces rendered side by side on one screen, with a seam
    /// between them. Not a party trick — it exercises exactly the same code path a
    /// real two-surface device would, which is how the split gets tested today.
    case duoRehearsal
    /// Stage on a connected external display, controls in the hand.
    case externalDisplay
    /// A real dual-screen device.
    case duo

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .solo:            "This Phone"
        case .duoRehearsal:    "Duo Rehearsal"
        case .externalDisplay: "Big Screen"
        case .duo:             "Duo"
        }
    }

    public var subtitle: String {
        switch self {
        case .solo:            "Stage and controls together"
        case .duoRehearsal:    "Both surfaces, side by side"
        case .externalDisplay: "Stage on the connected display"
        case .duo:             "Stage out, controls in"
        }
    }

    public var symbol: String {
        switch self {
        case .solo:            "iphone"
        case .duoRehearsal:    "rectangle.split.2x1"
        case .externalDisplay: "tv"
        case .duo:             "macbook.and.iphone"
        }
    }

    /// Roles this mode puts on screen at the same time.
    public var roles: Set<DisplayRole> {
        switch self {
        case .solo:            [.combined]
        case .duoRehearsal:    [.stage, .controls]
        case .externalDisplay: [.stage, .controls]
        case .duo:             [.stage, .controls]
        }
    }
}
