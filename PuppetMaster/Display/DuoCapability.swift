import Foundation

/// Physical description of a two-surface device.
///
/// Every number here is a **placeholder**, used by Duo Rehearsal to approximate the
/// layout. iPhone Duo is now announced, but iOS gives a non-camera app no second
/// surface on it (see `UnavailableDuoCapability`), so there is no real geometry to
/// substitute.
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
/// needs to know, not what a vendor might provide. See `ARCHITECTURE.md` §6.4.
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

/// What ships today, and — as of the iOS 27.1 SDK — what the platform allows.
///
/// iPhone Duo exists (announced September 2026, iOS 27.1, Xcode 27.1 beta has a
/// simulator). But its outer display is not a second surface an app can draw on. The
/// only public way to put content there is a *camera capture accessory*, which Apple
/// documents as available "while the app is in the foreground and has an active camera
/// capture session". A puppet show is not a camera session, and running one purely to
/// borrow the screen would mean a camera permission prompt for a children's toy that
/// never uses the camera — which is the wrong trade even before App Review sees it.
///
/// So this stays unavailable, and says so plainly. On iPhone Duo the useful thing is
/// the large inner display, where Duo Rehearsal already shows the stage and the
/// controls side by side. See `ARCHITECTURE.md` §6.4.
@MainActor
public final class UnavailableDuoCapability: DuoCapability {
    public init() {}

    public var availability: DuoAvailability {
        .unavailable(reason: """
            On iPhone Duo, iOS only lets camera apps use the outer screen, so the \
            puppet cannot perform there yet. Open the phone and choose Duo Rehearsal \
            to put the stage and the controls side by side on the big inner screen.
            """)
    }

    public var geometry: DuoGeometry { .placeholder }
}
