import SwiftUI

/// The performer-facing surface: the instrument.
///
/// Emits intents and nothing else. It never touches puppet state, which is what lets it
/// live on a different screen — or eventually a different half of a folding device —
/// from the stage it is driving.
///
/// The middle section scrolls. With twelve actions and seven expressions the panel no
/// longer fits every surface it can be mounted on (a phone, half a phone, a Duo inner
/// screen), and a control that is silently clipped off the bottom is worse than one you
/// have to reach for.
struct ControlsView: View {

    let engine: PuppetEngine
    let voice: VoiceInput
    let router: StageRouter
    let environment: AppEnvironment
    /// Shown when the performer cannot reach the stage to drag on it.
    var includesAimPad: Bool = false
    var isCompact: Bool = false
    var topInset: CGFloat = 12

    @State private var showingStage = false
    @State private var showingCast = false

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompact ? 66 : 74), spacing: 8)]
    }

    var body: some View {
        VStack(spacing: isCompact ? 8 : 10) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isCompact ? 8 : 10) {
                    expressionRow

                    LazyVGrid(columns: actionColumns, spacing: 8) {
                        ForEach(PuppetAction.allCases) { action in
                            PadButton(symbol: action.symbol,
                                      title: action.title,
                                      isBusy: engine.activeActions.contains(action),
                                      compact: isCompact) {
                                engine.send(.perform(action))
                                Haptics.action(action)
                            }
                        }
                    }

                    if includesAimPad {
                        AimPad(engine: engine)
                            .frame(height: isCompact ? 84 : 104)
                    } else {
                        // The drag-to-look gesture is the one thing nobody finds
                        // unprompted, and this band would otherwise be dead space.
                        Label("Drag on the stage to make \(engine.character.name) look around",
                              systemImage: "hand.draw.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.labelDim)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollBounceBehavior(.basedOnSize)

            TalkButton(engine: engine, voice: voice)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.panel)
        .sheet(isPresented: $showingStage) {
            StageSheet(router: router, environment: environment)
        }
        .sheet(isPresented: $showingCast) {
            CastSheet(engine: engine, environment: environment)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HeaderChip(symbol: "theatermasks.fill",
                       title: engine.character.name,
                       tint: Theme.accent) { showingCast = true }
                .accessibilityLabel("Character: \(engine.character.name)")
                .accessibilityHint("Choose who performs.")

            // Honest, visible proof that several surfaces are being driven at once.
            if engine.rendererCount > 1 {
                Label("\(engine.rendererCount)", systemImage: "rectangle.on.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.15)))
                    .accessibilityLabel("\(engine.rendererCount) surfaces")
            }

            Spacer(minLength: 4)

            HeaderChip(symbol: router.mode.symbol, title: router.mode.title) {
                showingStage = true
            }
            .accessibilityLabel("Stage mode: \(router.mode.title)")
            .accessibilityHint("Choose where the puppet performs.")
        }
    }

    /// Seven expressions do not fit a phone's width, so they scroll. Keeping them on one
    /// row matters more than seeing all of them: it stays a single gesture.
    private var expressionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Expression.allCases) { expression in
                    PadButton(symbol: expression.symbol,
                              title: expression.title,
                              isSelected: engine.expression == expression,
                              compact: isCompact) {
                        engine.send(.setExpression(expression))
                        Haptics.expressionChanged()
                    }
                    .frame(width: isCompact ? 70 : 78)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }
}
