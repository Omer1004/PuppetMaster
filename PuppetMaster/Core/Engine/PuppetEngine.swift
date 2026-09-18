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

    @ObservationIgnored private var blender = PoseBlender()
    @ObservationIgnored private var renderers: [WeakRenderer] = []

    public init() {
        blender.idle.adopt(character.personality)
    }

    // MARK: Renderers

    public func addRenderer(_ renderer: any PuppetRenderer) {
        renderers.removeAll { $0.value == nil }
        guard !renderers.contains(where: { $0.value === renderer }) else { return }
        renderers.append(WeakRenderer(renderer))
        renderer.load(character: character)
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
        let (pose, effects) = blender.tick(delta: delta)
        self.pose = pose

        let live = renderers.compactMap(\.value)
        for renderer in live {
            renderer.apply(pose: pose)
            for effect in effects { renderer.fire(effect: effect) }
        }
        if live.count != renderers.count { renderers.removeAll { $0.value == nil } }

        let actions = blender.actions.activeActions
        if actions != activeActions { activeActions = actions }
        let level = blender.live.jawDrive
        if abs(level - speechLevel) > 0.01 { speechLevel = level }
    }

    // MARK: Intents

    public func send(_ intent: PuppetIntent) {
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

        case .setExpression(let expression):
            guard expression != self.expression else { return }
            self.expression = expression
            blender.expression.set(expression)

        case .perform(let action):
            blender.actions.fire(action)
            activeActions = blender.actions.activeActions

        case .aim(let x, let y):
            blender.live.aim = SIMD2(x, y)
            if !isAiming { isAiming = true }

        case .releaseAim:
            blender.live.aim = nil
            if isAiming { isAiming = false }

        case .setMicEnabled(let enabled):
            isMicEnabled = enabled
            if !enabled { blender.live.jawDrive = 0 }

        case .setJawDrive(let level):
            blender.live.jawDrive = level.clamped(to: 0...1)
        }
    }

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
