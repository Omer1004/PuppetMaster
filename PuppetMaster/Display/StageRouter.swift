import Foundation
import Observation
import UIKit

/// Decides which surfaces exist and what goes on each one.
///
/// This is the **only** type in the app that knows how many screens there are.
/// `StageView` and `ControlsView` are written once and never learn which mode mounted
/// them — that ignorance is precisely what makes adding a surface cheap.
@MainActor
@Observable
public final class StageRouter {

    public private(set) var mode: PresentationMode = .solo

    /// Set once the user picks a mode by hand. After that the app stops second-guessing
    /// them when hardware appears.
    private var hasUserChosenMode = false

    /// Number of live external-display scenes. Maintained by
    /// ``ExternalDisplaySceneDelegate`` as the system connects and drops displays.
    public private(set) var externalSurfaceCount = 0

    public var isExternalDisplayConnected: Bool { externalSurfaceCount > 0 }

    public let duo: any DuoCapability

    public init(duo: any DuoCapability = UnavailableDuoCapability()) {
        self.duo = duo
    }

    // MARK: Availability

    /// Every mode, in the order they are offered. Unsupported ones are shown but
    /// disabled with a reason, rather than hidden — a silently missing option reads
    /// as a bug, and Duo in particular is worth advertising.
    public var allModes: [PresentationMode] { PresentationMode.allCases }

    public func isAvailable(_ mode: PresentationMode) -> Bool {
        switch mode {
        case .solo, .duoRehearsal: true
        case .externalDisplay:     isExternalDisplayConnected
        case .duo:                 duo.isAvailable
        }
    }

    public func unavailableReason(for mode: PresentationMode) -> String? {
        guard !isAvailable(mode) else { return nil }
        switch mode {
        case .externalDisplay:
            return "Connect a display with AirPlay or a cable, and the stage moves to it automatically."
        case .duo:
            return duo.unavailableReason
        case .solo, .duoRehearsal:
            return nil
        }
    }

    // MARK: Mode

    public func select(_ mode: PresentationMode) {
        guard isAvailable(mode) else { return }
        hasUserChosenMode = true
        self.mode = mode
    }

    /// What the phone itself should show. In Big Screen mode the stage has moved to
    /// the external display, so the phone is controls-only.
    public var roleForPrimarySurface: DisplayRole {
        switch mode {
        case .solo:            .combined
        case .duoRehearsal:    .combined     // both roles, but as two separate surfaces
        case .externalDisplay: .controls
        case .duo:             .controls
        }
    }

    // MARK: External display lifecycle

    func externalSurfaceConnected() {
        externalSurfaceCount += 1
        // Plugging in a display is an unambiguous request to use it — unless the user
        // deliberately chose a mode, in which case overriding them is rude.
        if mode == .solo, !hasUserChosenMode { mode = .externalDisplay }
    }

    func externalSurfaceDisconnected() {
        externalSurfaceCount = max(0, externalSurfaceCount - 1)
        if externalSurfaceCount == 0, mode == .externalDisplay { mode = .solo }
    }
}
