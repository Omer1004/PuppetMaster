import Foundation

/// Physical description of a two-surface device.
///
/// Every number here is a **placeholder**. No dual-screen iPhone SDK is public, so
/// these values are a plausible stand-in used by Duo Rehearsal mode to approximate
/// the layout — nothing more. When real hardware exists, these come from the SDK and
/// the rehearsal mode inherits the correction for free.
public struct DuoGeometry: Sendable, Equatable {
    /// Aspect ratio (width / height) of the audience-facing surface.
    public var stageAspect: Double
    /// Aspect ratio of the performer-facing surface.
    public var controlsAspect: Double
    /// Visual gap between the two surfaces, in points.
    public var seam: Double

    public static let placeholder = DuoGeometry(stageAspect: 0.78, controlsAspect: 0.62, seam: 14)
}

public enum DuoAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)
}

/// The single seam between this app and a dual-screen device.
///
/// **This is deliberately the only place in the codebase that knows Duo exists.**
/// Nothing here guesses at an API: the protocol is written in terms of what the *app*
/// needs to know, not what a vendor might one day provide. When an SDK ships, the work
/// is one new conformance plus a presenter — see `ARCHITECTURE.md` §6.4.
@MainActor
public protocol DuoCapability: AnyObject {
    var availability: DuoAvailability { get }
    var geometry: DuoGeometry { get }
}

extension DuoCapability {
    public var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }
    public var unavailableReason: String? {
        if case .unavailable(let reason) = availability { return reason }
        return nil
    }
}

/// What ships today.
///
/// Honest by construction: it reports Duo as unavailable and says why, instead of
/// pretending to detect hardware that nobody can buy. The app stays fully functional
/// without it, and Duo Rehearsal mode covers the layout work in the meantime.
@MainActor
public final class UnavailableDuoCapability: DuoCapability {
    public init() {}

    public var availability: DuoAvailability {
        .unavailable(reason: """
            No dual-screen device or SDK is available. Everything Duo mode needs is \
            already built and working — the stage and the controls are independent \
            surfaces driven by one engine. Try Duo Rehearsal to see both at once.
            """)
    }

    public var geometry: DuoGeometry { .placeholder }
}
