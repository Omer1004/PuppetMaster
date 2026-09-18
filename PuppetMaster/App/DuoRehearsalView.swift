import SwiftUI

/// Both surfaces at once, on one phone.
///
/// Not a mock-up. The two panels host the *same* `StageView` and `ControlsView` that a
/// real two-screen device would put on separate displays, driven by the same engine
/// through the same intents. The only thing being simulated is the hardware seam.
///
/// This is how the Duo layout gets designed, tested and critiqued before the hardware
/// exists — and it is the insurance policy on the whole Duo bet: if the stage/controls
/// split were wrong, it would be obvious here rather than after an SDK lands.
struct DuoRehearsalView: View {

    let environment: AppEnvironment

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > geometry.size.height
            let geo = environment.router.duo.geometry

            Group {
                if isWide {
                    HStack(spacing: geo.seam) {
                        stagePanel
                        controlsPanel
                    }
                } else {
                    VStack(spacing: geo.seam) {
                        stagePanel
                        controlsPanel
                    }
                }
            }
            .padding(geo.seam)
            .background(Color.black)
        }
        .overlay(alignment: .bottom) {
            Text("Placeholder geometry — real proportions come from the device SDK")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.labelDim)
                .padding(.bottom, 2)
        }
    }

    private var stagePanel: some View {
        panel(label: "Outer screen · audience", symbol: "person.2.fill") {
            // Not interactive: on real hardware the audience side is facing away.
            StageView(engine: environment.engine,
                      backdrop: environment.backdrop,
                      isInteractive: false)
        }
    }

    private var controlsPanel: some View {
        panel(label: "Inner screen · performer", symbol: "hand.point.up.left.fill") {
            ControlsView(engine: environment.engine,
                         voice: environment.voice,
                         router: environment.router,
                         environment: environment,
                         includesAimPad: true,
                         isCompact: true,
                         topInset: 30)   // clears the surface badge
        }
    }

    private func panel<Content: View>(label: String,
                                      symbol: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        content()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Label(label, systemImage: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(7)
            }
    }
}
