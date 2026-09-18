import SwiftUI

/// Picks a layout for whatever surfaces currently exist.
///
/// Every branch below composes the *same* `StageView` and `ControlsView`. Nothing is
/// duplicated per mode, which is the property that has to hold for a second screen to
/// stay cheap.
struct RootView: View {

    private let environment = AppEnvironment.shared
    @AppStorage("hasSeenCoachCard") private var hasSeenCoachCard = false

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()

            switch environment.router.mode {
            case .solo:
                soloLayout
            case .duoRehearsal:
                DuoRehearsalView(environment: environment)
            case .externalDisplay:
                bigScreenLayout
            case .duo:
                // Not reachable today: the router will not select an unavailable mode.
                // Controls-only is the correct fallback if it ever is.
                ControlsView(engine: environment.engine,
                             voice: environment.voice,
                             router: environment.router,
                             environment: environment,
                             includesAimPad: true)
            }

            if !hasSeenCoachCard {
                CoachCard(characterName: environment.engine.character.name) {
                    hasSeenCoachCard = true
                }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: environment.router.mode)
        .preferredColorScheme(.dark)
        .statusBarHidden(environment.router.mode != .solo)
    }

    // MARK: Solo — one phone, stage above controls

    private var soloLayout: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                StageView(engine: environment.engine)
                    .frame(height: geometry.size.height * 0.54)
                    .clipped()

                ControlsView(engine: environment.engine,
                             voice: environment.voice,
                             router: environment.router,
                             environment: environment)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Big Screen — stage is on the connected display

    private var bigScreenLayout: some View {
        VStack(spacing: 0) {
            // Confidence monitor. A performer whose stage is across the room still
            // needs to see what the audience sees — and it is a second live surface,
            // driven by the same engine and the same frame.
            ZStack(alignment: .topLeading) {
                StageView(engine: environment.engine, isInteractive: false)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Label("On the big screen", systemImage: "tv")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ControlsView(engine: environment.engine,
                         voice: environment.voice,
                         router: environment.router,
                         environment: environment,
                         includesAimPad: true,
                         isCompact: true,
                         topInset: 8)
        }
    }
}

/// First-run coaching. One card, dismissed by any tap, never shown again.
private struct CoachCard: View {
    let characterName: String
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Meet \(characterName)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 10) {
                    row("hand.tap.fill", "Tap a button to make \(characterName) move.")
                    row("mic.fill", "Hold Talk and its mouth follows your voice.")
                    row("hand.draw.fill", "Drag on the stage to make it look around.")
                }
                Text("Tap anywhere to start")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.labelDim)
                    .padding(.top, 4)
            }
            .foregroundStyle(Theme.label)
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.panel))
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityAddTraits(.isModal)
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(text).font(.system(size: 15))
        }
    }
}

/// The audience-facing surface, as hosted on an external display.
///
/// A view rather than an inline `StageView` so that observation works: reading
/// `environment.backdrop` inside `body` is what makes a backdrop change on the phone
/// reach the screen across the room.
struct AudienceStageView: View {
    private let environment = AppEnvironment.shared

    var body: some View {
        StageView(engine: environment.engine, isInteractive: false)
            .ignoresSafeArea()
    }
}
