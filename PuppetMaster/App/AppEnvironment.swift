import Observation
import UIKit

/// Composition root. The only place the pieces are wired together.
///
/// A single shared instance, because several scenes — the phone and an external
/// display — must drive *one* performance. Two engines would mean two puppets that
/// drift apart within seconds.
@MainActor
@Observable
final class AppEnvironment {

    static let shared = AppEnvironment()

    let engine = PuppetEngine()
    let router = StageRouter()
    let voice = VoiceInput()

    @ObservationIgnored private var clock: EngineClock?
    @ObservationIgnored private var reduceMotionObserver: (any NSObjectProtocol)?

    private init() {
        clock = EngineClock { [weak self] delta in self?.frame(delta) }
        applyReduceMotion()
        reduceMotionObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppEnvironment.shared.applyReduceMotion() }
            }
        Haptics.prepare()
    }

    /// One frame, for every surface at once.
    private func frame(_ delta: Double) {
        engine.send(.setJawDrive(voice.level(delta: delta)))
        engine.tick(delta: delta)
    }

    func startClock() { clock?.start() }
    func stopClock() { clock?.stop() }

    /// Reduced motion damps the idle layer rather than switching it off. A completely
    /// still puppet reads as a crashed app, which serves nobody.
    private func applyReduceMotion() {
        engine.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
    }

    // Intentionally no deallocation hook: this is a process-lifetime singleton, so the
    // observer is released with the app. Under Swift 6 strict concurrency a nonisolated
    // deallocator cannot touch main-actor state anyway.
}
