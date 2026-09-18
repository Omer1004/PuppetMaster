import SwiftUI
import SpriteKit

/// The audience-facing surface.
///
/// Knows nothing about which mode mounted it. The same view is used for the top half
/// of a single phone, a whole external display, and one side of Duo Rehearsal — the
/// only difference is who puts it on screen and whether it accepts touches.
struct StageView: View {

    let engine: PuppetEngine
    var backdrop: Backdrop = BackdropLibrary.default
    /// False for an audience-facing surface: the stage on a TV is not a control.
    var isInteractive: Bool = true

    @State private var scene = PuppetScene(size: CGSize(width: 390, height: 520))
    @State private var isAiming = false

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
                    ? "Drag anywhere to make Moppet look that way."
                    : "Shows the puppet performance.")
        }
        .onAppear {
            scene.setBackdrop(backdrop)
            engine.addRenderer(scene)
        }
        .onDisappear { engine.removeRenderer(scene) }
        .onChange(of: backdrop) { _, new in scene.setBackdrop(new) }
    }

    private func aimGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractive, size.width > 0, size.height > 0 else { return }
                isAiming = true
                // Normalise to -1…1 with the origin at the puppet's head, which sits
                // above centre — aiming at the middle of the stage should read as
                // looking straight ahead, not downward.
                let x = (value.location.x / size.width) * 2 - 1
                let y = 1 - (value.location.y / (size.height * 0.75)) * 2
                engine.send(.aim(x: Double(x), y: Double(y)))
            }
            .onEnded { _ in
                guard isInteractive else { return }
                isAiming = false
                engine.send(.releaseAim)
            }
    }
}
