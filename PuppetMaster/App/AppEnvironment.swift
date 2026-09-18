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

    /// Where the puppet performs. Kept here rather than on the engine because it is
    /// staging, not behaviour — any character can play against any backdrop.
    private(set) var backdrop: Backdrop = BackdropLibrary.default

    @ObservationIgnored private var clock: EngineClock?
    @ObservationIgnored private var reduceMotionObserver: (any NSObjectProtocol)?

    private init() {
        restoreChoices()
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

    // MARK: Cast and staging

    func selectCharacter(id: String) {
        engine.send(.setCharacter(id: id))
        defaults.set(id, forKey: Key.character)
    }

    func selectBackdrop(_ backdrop: Backdrop) {
        guard backdrop != self.backdrop else { return }
        self.backdrop = backdrop
        defaults.set(backdrop.id, forKey: Key.backdrop)
    }

    /// Bring back whatever the user was last performing with. Losing your character on
    /// every launch would be a small betrayal every time.
    private func restoreChoices() {
        if let id = defaults.string(forKey: Key.character) {
            engine.send(.setCharacter(id: id))
        }
        if let id = defaults.string(forKey: Key.backdrop) {
            backdrop = BackdropLibrary.backdrop(id: id)
        }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    private enum Key {
        static let character = "selectedCharacter"
        static let backdrop = "selectedBackdrop"
    }

    // MARK: Clock

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
