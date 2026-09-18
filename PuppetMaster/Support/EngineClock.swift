import QuartzCore
import UIKit

/// Drives one frame of the performance from the display refresh.
///
/// The clock lives outside `Core/` on purpose: the engine takes a delta and knows
/// nothing about `CADisplayLink`, screens, or app lifecycle — which is what lets the
/// whole feel of the puppet be unit-tested at thousands of frames per second with no
/// simulator attached.
///
/// One clock per app, never one per surface. Several renderers share a single
/// performance; two stages ticking on their own clocks would drift apart in seconds.
@MainActor
final class EngineClock {

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private let onFrame: (Double) -> Void

    init(onFrame: @escaping (Double) -> Void) {
        self.onFrame = onFrame
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        // Content at 60; takes 120 Hz where the panel offers it.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
        lastTimestamp = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = 0
    }

    @objc private func step(_ link: CADisplayLink) {
        guard lastTimestamp > 0 else { lastTimestamp = link.timestamp; return }
        let delta = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        onFrame(delta)
    }

    // Intentionally no deallocation hook. A scheduled CADisplayLink is retained by the
    // run loop and retains its target, so this object cannot be torn down while a link
    // is live — `stop()` must already have run.
}
