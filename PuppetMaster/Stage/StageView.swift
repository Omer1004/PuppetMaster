import SwiftUI
import SpriteKit

/// The audience-facing surface.
///
/// Knows nothing about which mode mounted it. The same view is used for the top half
/// of a single phone, a whole external display, and one side of Duo Rehearsal — the
/// only difference is who puts it on screen and whether it accepts touches.
struct StageView: View {

    let engine: PuppetEngine
    /// False for an audience-facing surface: the stage on a TV is not a control.
    var isInteractive: Bool = true

    @State private var scene = PuppetScene(size: CGSize(width: 390, height: 520))
    @State private var touchStartedAt: Date?

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(aimGesture(in: geometry.size))
                .allowsHitTesting(isInteractive)
                .accessibilityElement()
                .accessibilityLabel("Puppet stage")
                .accessibilityHint(isInteractive
                    ? "Drag to make \(engine.character.name) look around, or tap to poke."
                    : "Shows the puppet performance.")
        }
        .onAppear { engine.addRenderer(scene) }
        .onDisappear { engine.removeRenderer(scene) }
    }

    private func aimGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractive, size.width > 0, size.height > 0 else { return }
                if touchStartedAt == nil { touchStartedAt = Date() }
                // Normalise to -1…1 with the origin at the puppet's head, which sits
                // above centre — aiming at the middle of the stage should read as
                // looking straight ahead, not downward.
                let x = (value.location.x / size.width) * 2 - 1
                let y = 1 - (value.location.y / (size.height * 0.75)) * 2
                engine.send(.aim(x: Double(x), y: Double(y)))
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
                    engine.send(.poke(x: Double((value.location.x / size.width) * 2 - 1),
                                      y: Double(1 - (value.location.y / (size.height * 0.75)) * 2)))
                    Haptics.tick(intensity: 0.7)
                } else {
                    engine.send(.releaseAim)
                }
            }
    }
}
