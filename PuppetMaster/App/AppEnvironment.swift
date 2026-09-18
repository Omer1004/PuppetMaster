import Observation
import UIKit

/// Composition root. The only place the pieces are wired together.
///
/// A single shared instance, because several *surfaces* — the phone and an external
/// display — must show *one* performance. Surfaces are renderers attached to an engine;
/// giving a surface its own engine would mean two puppets that drift apart within
/// seconds. A second *puppet* is a different thing entirely and does get its own engine:
/// see ``Troupe``.
@MainActor
@Observable
final class AppEnvironment {

    static let shared = AppEnvironment()

    /// Who is on stage. One puppet, or two in a duet — see ``Troupe``.
    let troupe = Troupe()
    let router = StageRouter()
    let voice = VoiceInput()
    let sound = SoundBank()
    /// Optional, unadvertised, and gates nothing. See ``TipJar``.
    let tipJar = TipJar()

    /// Staging lives on the engine so it reaches every surface the same way a pose
    /// does. This type is the *command* layer: it turns a tap into an intent and
    /// remembers the choice. See ARCHITECTURE §4.1.
    var backdrop: Backdrop { engine.backdrop }

    /// The puppet the controls are driving. Almost everything wants this rather than the
    /// troupe, because almost everything is about one puppet at a time.
    var engine: PuppetEngine { troupe.focused }

    @ObservationIgnored private var clock: EngineClock?
    @ObservationIgnored private var reduceMotionObserver: (any NSObjectProtocol)?

    private init() {
        // Sound is emitted once per performance, not once per surface — the engine hands
        // it here rather than to renderers, so two stages do not double every noise.
        troupe.onSound = { [sound] id, pitch in
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
        // Your voice drives the puppet you are holding, not both of them — a duet where
        // both mouths move to one voice looks like a glitch, not a conversation.
        troupe.send(.setJawDrive(voice.level(delta: delta)))
        troupe.tick(delta: delta)
    }

    // MARK: Duet

    func setDuet(_ duet: Bool) {
        troupe.setDuet(duet)
        // `Troupe` gives the new slot a stand-in so a duet is never one puppet twice.
        // If the user has already chosen someone for that slot, their choice wins —
        // without this, the remembered pair only came back across a relaunch.
        if duet { restorePartnerCharacter() }
        defaults.set(duet, forKey: Key.duet)
    }

    private func restorePartnerCharacter() {
        guard let id = defaults.string(forKey: Key.character(slot: 1)),
              troupe.engines.indices.contains(1) else { return }
        troupe.engines[1].send(.setCharacter(id: id))
    }

    var isDuet: Bool { troupe.isDuet }

    // MARK: Cast and staging

    /// Change who the *focused* puppet is. In a duet each slot remembers its own
    /// character, so turning the duet back on brings back the pair you had.
    func selectCharacter(id: String) {
        troupe.focused.send(.setCharacter(id: id))
        defaults.set(id, forKey: Key.character(slot: troupe.focusIndex))
    }

    /// Staging is shared: two puppets on one stage cannot stand under two skies.
    func selectBackdrop(_ backdrop: Backdrop) {
        troupe.setBackdrop(backdrop)
        defaults.set(backdrop.id, forKey: Key.backdrop)
    }

    /// Bring back whatever the user was last performing with. Losing your character on
    /// every launch would be a small betrayal every time.
    private func restoreChoices() {
        if let id = defaults.string(forKey: Key.character(slot: 0)) {
            troupe.engines[0].send(.setCharacter(id: id))
        }
        if let id = defaults.string(forKey: Key.backdrop) {
            troupe.setBackdrop(BackdropLibrary.backdrop(id: id))
        }
        // The duet comes back before its second character does: `setDuet` picks a
        // stand-in for the empty slot, and the remembered choice then replaces it.
        if defaults.bool(forKey: Key.duet) {
            troupe.setDuet(true)
            restorePartnerCharacter()
        }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    private enum Key {
        static func character(slot: Int) -> String {
            slot == 0 ? "selectedCharacter" : "selectedCharacter\(slot)"
        }
        static let backdrop = "selectedBackdrop"
        static let duet = "duetMode"
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
        troupe.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
    }

    // Intentionally no deallocation hook: this is a process-lifetime singleton, so the
    // observer is released with the app. Under Swift 6 strict concurrency a nonisolated
    // deallocator cannot touch main-actor state anyway.
}
