import SwiftUI
import SpriteKit

/// The audience-facing surface.
///
/// Knows nothing about which mode mounted it. The same view is used for the top half
/// of a single phone, a whole external display, and one side of Duo Rehearsal — the
/// only difference is who puts it on screen and whether it accepts touches.
struct StageView: View {

    let troupe: Troupe
    /// False for an audience-facing surface: the stage on a TV is not a control.
    var isInteractive: Bool = true

    /// Held behind a box that builds the scene lazily.
    ///
    /// `@State private var scene = PuppetScene(...)` looks equivalent and is not: the
    /// initial value is evaluated every time the struct is initialised, and SwiftUI then
    /// throws the new one away if state already exists. `RootView`'s body re-evaluates
    /// on every observation change, so that was a whole `SKScene` — and a
    /// `StagePerformer` — built and discarded on each one.
    @State private var sceneBox = SceneBox()
    private var scene: PuppetScene { sceneBox.scene }
    @State private var touchStartedAt: Date?
    /// Which puppet the current touch started on, so a drag that wanders across the
    /// middle keeps driving the puppet it began with.
    @State private var touchedIndex = 0

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(aimGesture(in: geometry.size))
                .allowsHitTesting(isInteractive)
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(isInteractive
                    ? "Drag to make the puppet look around, or tap to poke."
                    : "Shows the puppet performance.")
        }
        .onAppear { attach() }
        .onDisappear { detach() }
        .onChange(of: troupe.engines.count) { attach() }
        .onChange(of: troupe.focusIndex) {
            scene.setFocus(troupe.isDuet ? troupe.focusIndex : nil)
        }
    }

    private var accessibilityLabel: String {
        troupe.isDuet
            ? "Puppet stage with \(troupe.engines.map(\.character.name).joined(separator: " and "))"
            : "Puppet stage with \(troupe.focused.character.name)"
    }

    /// Give every puppet a place on this stage and register it with its own engine.
    /// Re-run whenever the cast size changes, which is the only thing that moves a
    /// renderer from one engine to another.
    private func attach() {
        detach()
        scene.setPerformerCount(troupe.engines.count)
        for (index, engine) in troupe.engines.enumerated() {
            guard let performer = scene.performer(at: index) else { continue }
            engine.addRenderer(performer)
        }
        scene.setFocus(troupe.isDuet ? troupe.focusIndex : nil)
    }

    private func detach() {
        for engine in troupe.engines {
            for performer in scene.performers { engine.removeRenderer(performer) }
        }
    }

    private func aimGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractive, size.width > 0, size.height > 0 else { return }
                if touchStartedAt == nil {
                    touchStartedAt = Date()
                    // Touching a puppet is also how you choose it. Nothing else is
                    // needed for a duet on one phone: you drive whoever you touched.
                    touchedIndex = scene.performerIndex(atX: value.startLocation.x)
                    troupe.focus(touchedIndex)
                }
                // Normalise to -1…1 with the origin at the puppet's head, which sits
                // above centre — aiming at the middle of the stage should read as
                // looking straight ahead, not downward.
                let (x, y) = normalise(value.location, in: size)
                troupe.send(.aim(x: x, y: y), to: touchedIndex)
            }
            .onEnded { value in
                guard isInteractive, size.width > 0, size.height > 0 else { return }
                let began = touchStartedAt
                touchStartedAt = nil

                // A quick tap that barely moved is a poke, not an aim. Nothing tells you
                // the puppet can be prodded, which is exactly why finding out is a treat.
                let travel = hypot(value.translation.width, value.translation.height)
                let held = began.map { Date().timeIntervalSince($0) } ?? 0
                if travel < 12, held < 0.4 {
                    let (x, y) = normalise(value.location, in: size)
                    troupe.send(.poke(x: x, y: y), to: touchedIndex)
                    Haptics.tick(intensity: 0.7)
                } else {
                    troupe.send(.releaseAim, to: touchedIndex)
                }
            }
    }

    /// Stage point to aim coordinates, relative to the puppet that was touched. In a
    /// duet each puppet's own slot is its whole world, so dragging over one puppet aims
    /// its eyes across its own range rather than a half-range.
    private func normalise(_ point: CGPoint, in size: CGSize) -> (Double, Double) {
        let slots = CGFloat(troupe.engines.count)
        let slotWidth = size.width / slots
        let localX = point.x - slotWidth * CGFloat(touchedIndex)
        return (Double((localX / slotWidth) * 2 - 1),
                Double(1 - (point.y / (size.height * 0.75)) * 2))
    }
}

/// Lazy storage for the scene. A plain reference type, not observable: nothing about it
/// changes, it exists so that constructing `StageView` costs nothing.
@MainActor
private final class SceneBox {
    lazy var scene = PuppetScene(size: CGSize(width: 390, height: 520))
}
