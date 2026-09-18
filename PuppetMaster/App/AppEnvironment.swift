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
    let sound = SoundBank()

    /// Staging lives on the engine so it reaches every surface the same way a pose
    /// does. This type is the *command* layer: it turns a tap into an intent and
    /// remembers the choice. See ARCHITECTURE §4.1.
    var backdrop: Backdrop { engine.backdrop }

    @ObservationIgnored private var clock: EngineClock?
    @ObservationIgnored private var reduceMotionObserver: (any NSObjectProtocol)?

    private init() {
        // Sound is emitted once per performance, not once per surface — the engine hands
        // it here rather than to renderers, so two stages do not double every noise.
        engine.onSound = { [sound] id, pitch in
            sound.play(id, pitch: pitch)
            // Haptics on the animation's beat rather than on the button press. Feeling a
            // landing at the moment it lands is most of why it reads as weight.
            switch id {
            case .thud:   Haptics.impact(0.95)
            case .boing:  Haptics.impact(0.55)
            case .squeak: Haptics.impact(0.40)
            default:      break
            }
        }
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
        engine.send(.setBackdrop(id: backdrop.id))
        defaults.set(backdrop.id, forKey: Key.backdrop)
    }

    /// Bring back whatever the user was last performing with. Losing your character on
    /// every launch would be a small betrayal every time.
    private func restoreChoices() {
        if let id = defaults.string(forKey: Key.character) {
            engine.send(.setCharacter(id: id))
        }
        if let id = defaults.string(forKey: Key.backdrop) {
            engine.send(.setBackdrop(id: id))
        }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    private enum Key {
        static let character = "selectedCharacter"
        static let backdrop = "selectedBackdrop"
    }

    // MARK: Clock

    func startClock() {
        sound.start()
        clock?.start()
    }
    func stopClock() {
        clock?.stop()
        sound.stop()
    }

    /// Reduced motion damps the idle layer rather than switching it off. A completely
    /// still puppet reads as a crashed app, which serves nobody.
    private func applyReduceMotion() {
        engine.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
    }

    // Intentionally no deallocation hook: this is a process-lifetime singleton, so the
    // observer is released with the app. Under Swift 6 strict concurrency a nonisolated
    // deallocator cannot touch main-actor state anyway.
}
