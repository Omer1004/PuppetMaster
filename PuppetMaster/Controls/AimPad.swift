import SwiftUI

/// A trackpad for aiming the puppet's gaze.
///
/// Needed whenever the performer cannot reach the stage — Big Screen mode, and the
/// controls half of a two-surface device. In Solo mode you just drag on the stage
/// itself, so this is left out rather than duplicated.
struct AimPad: View {

    let engine: PuppetEngine
    @State private var knob: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.panelRaised)

                // Crosshair, so it is obvious this is an aiming surface and not a pad
                // of buttons waiting to be discovered.
                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: 14))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height - 14))
                    path.move(to: CGPoint(x: 14, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width - 14, y: size.height / 2))
                }
                .stroke(Theme.labelDim.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                if let knob {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 30, height: 30)
                        .position(knob)
                        .allowsHitTesting(false)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Look")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.labelDim)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard size.width > 0, size.height > 0 else { return }
                        let clamped = CGPoint(
                            x: value.location.x.clamped(to: 0...size.width),
                            y: value.location.y.clamped(to: 0...size.height))
                        knob = clamped
                        engine.send(.aim(x: Double((clamped.x / size.width) * 2 - 1),
                                         y: Double(1 - (clamped.y / size.height) * 2)))
                    }
                    .onEnded { _ in
                        knob = nil
                        engine.send(.releaseAim)
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Look pad")
        .accessibilityHint("Drag to make Moppet look around.")
    }
}
