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
            let layout = StageLayout.forSurface(width: geometry.size.width,
                                                height: geometry.size.height)

            if layout.isSideBySide {
                // Landscape. The stage keeps the side the safe area is least likely to
                // eat into, and the controls get the aim pad: in this orientation the
                // stage is across the screen from your thumbs, so dragging on it to
                // look around is no longer the comfortable gesture it is in portrait.
                HStack(spacing: 0) {
                    StageView(troupe: environment.troupe)
                        .frame(width: geometry.size.width * layout.fraction)
                        .clipped()

                    ControlsView(engine: environment.engine,
                                 voice: environment.voice,
                                 router: environment.router,
                                 environment: environment,
                                 includesAimPad: true,
                                 isCompact: true,
                                 topInset: 8)
                }
                .ignoresSafeArea(edges: .leading)
            } else {
                VStack(spacing: 0) {
                    StageView(troupe: environment.troupe)
                        .frame(height: geometry.size.height * layout.fraction)
                        .clipped()

                    ControlsView(engine: environment.engine,
                                 voice: environment.voice,
                                 router: environment.router,
                                 environment: environment)
                }
                .ignoresSafeArea(edges: .top)
            }
        }
    }

    // MARK: Big Screen — stage is on the connected display

    private var bigScreenLayout: some View {
        VStack(spacing: 0) {
            // Confidence monitor. A performer whose stage is across the room still
            // needs to see what the audience sees — and it is a second live surface,
            // driven by the same engine and the same frame.
            ZStack(alignment: .topLeading) {
                StageView(troupe: environment.troupe, isInteractive: false)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Label("On the big screen", systemImage: "tv")
                    .font(.system(.caption2).weight(.bold))
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

    @ScaledMetric(relativeTo: .body) private var rowIconWidth: CGFloat = 26

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            // The card keeps its natural size until it no longer fits, and only then
            // starts scrolling. At the largest accessibility text sizes three sentences
            // are taller than the phone, and a first-run card you cannot read all of is
            // worse than no card at all.
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card }.scrollBounceBehavior(.basedOnSize)
            }
            .foregroundStyle(Theme.label)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.panel))
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text("Meet \(characterName)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                row("hand.tap.fill", "Tap a button to make \(characterName) move.")
                row("mic.fill", "Hold Talk and its mouth follows your voice.")
                row("hand.draw.fill", "Drag on the stage to make it look around.")
            }
            Text("Tap anywhere to start")
                .font(.system(.footnote).weight(.semibold))
                .foregroundStyle(Theme.labelDim)
                .padding(.top, 4)
        }
        .padding(28)
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(.body))
                .foregroundStyle(Theme.accent)
                .frame(width: rowIconWidth)
            Text(text).font(.system(.subheadline))
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
        StageView(troupe: environment.troupe, isInteractive: false)
            .ignoresSafeArea()
    }
}
