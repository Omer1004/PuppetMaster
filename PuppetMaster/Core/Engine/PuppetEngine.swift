import Foundation
import Observation

/// The single source of truth for the puppet.
///
/// Views never own animation state. Controls post ``PuppetIntent`` values; renderers
/// receive finished poses. Nothing else talks to anything else.
///
/// The engine pushes each frame to *every* registered renderer, which is how one
/// performance can drive several surfaces at once — the phone's stage plus an
/// external display, or the two halves of a folding device. Adding a surface adds a
/// renderer; it does not add engine code.
@MainActor
@Observable
public final class PuppetEngine: IntentSink {

    // MARK: Observed state (read by control surfaces)

    public private(set) var character: CharacterDescriptor = CharacterLibrary.default
    public private(set) var backdrop: Backdrop = BackdropLibrary.default
    public private(set) var expression: Expression = .neutral
    public private(set) var activeActions: Set<PuppetAction> = []
    public private(set) var isMicEnabled = false
    public private(set) var isAiming = false
    /// Smoothed 0…1 speech level, for the talk button's level meter.
    public private(set) var speechLevel: Double = 0

    /// The current frame. Renderers are pushed to directly; this is here for previews,
    /// debugging and tests.
    public private(set) var pose: PuppetPose = .neutral

    // MARK: Internals

    /// Sound is emitted once per *performance*, not once per surface. Renderers get
    /// poses and effects; audio deliberately does not go through them, or a second
    /// stage would double every sound.
    @ObservationIgnored public var onSound: ((SoundID, Double) -> Void)?

    @ObservationIgnored private var blender = PoseBlender()
    @ObservationIgnored private var renderers: [WeakRenderer] = []

    /// Seconds since the performer last did anything, and how far up the boredom
    /// ladder we have climbed.
    @ObservationIgnored private var idleSeconds: Double = 0
    @ObservationIgnored private var idleBeatIndex = 0
    @ObservationIgnored private var pokeAimSeconds: Double = 0

    /// What an unattended puppet does, and how long it waits each time.
    ///
    /// This is the whole engagement design, and it is deliberately the *only* one: a
    /// character that gets visibly bored is a reason to pick the phone back up, and it
    /// costs the user nothing when they don't. No streaks, no timers, no notifications.
    private static let boredomLadder: [(wait: Double, action: PuppetAction)] = [
        (14, .stretch),   // a yawn — "are you still there?"
        (11, .peek),      // hides, checks whether that got your attention
        (15, .dance),     // entertains itself
    ]

    public init() {
        blender.idle.adopt(character.personality)
    }

    // MARK: Renderers

    public func addRenderer(_ renderer: any PuppetRenderer) {
        renderers.removeAll { $0.value == nil }
        guard !renderers.contains(where: { $0.value === renderer }) else { return }
        renderers.append(WeakRenderer(renderer))
        renderer.load(character: character)
        renderer.setBackdrop(backdrop)
        renderer.apply(pose: pose)   // a surface must never appear blank for a frame
    }

    public func removeRenderer(_ renderer: any PuppetRenderer) {
        renderers.removeAll { $0.value == nil || $0.value === renderer }
    }

    /// How many surfaces are currently being driven. Shown in the debug overlay, and
    /// the simplest honest proof that multi-surface output is actually working.
    public var rendererCount: Int { renderers.filter { $0.value != nil }.count }

    // MARK: Clock

    /// Advance the performance by one frame. Driven by ``EngineClock``.
    public func tick(delta: Double) {
        let (pose, cues) = blender.tick(delta: delta)
        self.pose = pose

        let live = renderers.compactMap(\.value)
        for renderer in live {
            renderer.apply(pose: pose)
            for effect in cues.effects { renderer.fire(effect: effect) }
        }
        if live.count != renderers.count { renderers.removeAll { $0.value == nil } }

        // The character's own voice is applied here, so a cue can stay character-agnostic.
        let voice = character.personality.voicePitch
        for hit in cues.sounds { onSound?(hit.sound, hit.pitch * voice) }

        updateBoredom(delta: delta)
        updatePokeAim(delta: delta)

        let actions = blender.actions.activeActions
        if actions != activeActions { activeActions = actions }
        let level = blender.live.jawDrive
        if abs(level - speechLevel) > 0.01 { speechLevel = level }
    }

    // MARK: Intents

    public func send(_ intent: PuppetIntent) {
        noteActivity(for: intent)

        switch intent {
        case .setCharacter(let id):
            let next = CharacterLibrary.character(id: id)
            guard next.id != character.id else { return }
            character = next
            // Personality lives in the idle layer, so swapping the cast changes how the
            // puppet breathes and blinks, not just how it looks.
            blender.idle.adopt(next.personality)
            // An in-flight action belongs to the character that started it.
            blender.actions.cancelAll()
            for renderer in renderers.compactMap(\.value) {
                renderer.load(character: next)
                renderer.apply(pose: pose)
            }

        case .setBackdrop(let id):
            let next = BackdropLibrary.backdrop(id: id)
            guard next != backdrop else { return }
            backdrop = next
            for renderer in renderers.compactMap(\.value) { renderer.setBackdrop(next) }

        case .setExpression(let expression):
            guard expression != self.expression else { return }
            self.expression = expression
            blender.expression.set(expression)

        case .perform(let action):
            blender.actions.fire(action)
            activeActions = blender.actions.activeActions

        case .aim(let x, let y):
            blender.live.aim = SIMD2(x, y)
            pokeAimSeconds = 0          // a real drag takes over from a poke
            if !isAiming { isAiming = true }

        case .releaseAim:
            blender.live.aim = nil
            pokeAimSeconds = 0
            if isAiming { isAiming = false }

        case .poke(let x, let y):
            // Prodding the puppet is the one interaction nobody is told about, so it has
            // to be worth finding: it startles, squeaks, and looks straight at your finger.
            blender.actions.fire(.flinch)
            blender.live.aim = SIMD2(x, y)
            pokeAimSeconds = 1.1
            isAiming = true
            activeActions = blender.actions.activeActions

        case .setMicEnabled(let enabled):
            isMicEnabled = enabled
            if !enabled { blender.live.jawDrive = 0 }

        case .setJawDrive(let level):
            blender.live.jawDrive = level.clamped(to: 0...1)
        }
    }

    // MARK: Boredom

    /// Let the puppet get visibly bored. Only ever while nothing else is happening, and
    /// the clock restarts the moment the performer does anything at all.
    private func updateBoredom(delta: Double) {
        guard boredomEnabled else { return }
        guard blender.actions.activeActions.isEmpty else { return }

        idleSeconds += delta
        let beat = Self.boredomLadder[idleBeatIndex % Self.boredomLadder.count]
        guard idleSeconds >= beat.wait else { return }

        blender.actions.fire(beat.action)
        activeActions = blender.actions.activeActions
        idleBeatIndex += 1
        idleSeconds = 0
    }

    /// A poke aims the gaze at your finger, then lets it drift back on its own.
    private func updatePokeAim(delta: Double) {
        guard pokeAimSeconds > 0 else { return }
        pokeAimSeconds -= delta
        guard pokeAimSeconds <= 0 else { return }
        blender.live.aim = nil
        isAiming = false
    }

    private func noteActivity(for intent: PuppetIntent) {
        // Holding Talk sends a jaw level every frame; silence should not count as
        // activity or the puppet would never get bored while the button is merely held.
        if case .setJawDrive(let level) = intent, level < 0.05 { return }
        idleSeconds = 0
        idleBeatIndex = 0
    }

    /// Stagger this puppet's boredom clock.
    ///
    /// Two puppets that start together climb the boredom ladder in lockstep and yawn in
    /// unison, which reads as one mechanism rather than two characters with their own
    /// attention spans.
    public func offsetIdleClock(by seconds: Double) {
        idleSeconds = seconds
    }

    /// Turned off for tests and for surfaces where a puppet acting on its own would be
    /// a distraction rather than a delight.
    public var boredomEnabled = true

    /// Scale down idle motion when the system asks for reduced motion. Not switched
    /// off — a motionless puppet reads as broken, which helps nobody.
    public func setReduceMotion(_ reduced: Bool) {
        blender.idle.intensity = reduced ? 0.25 : 1
    }
}

private struct WeakRenderer {
    weak var value: (any PuppetRenderer)?
    init(_ value: any PuppetRenderer) { self.value = value }
}
