import SwiftUI

/// The performer-facing surface: the instrument.
///
/// Emits intents and nothing else. It never touches puppet state, which is what lets
/// it live on a different screen — or eventually a different half of a folding device
/// — from the stage it is driving.
struct ControlsView: View {

    let engine: PuppetEngine
    let voice: VoiceInput
    let router: StageRouter
    /// Shown when the performer cannot reach the stage to drag on it.
    var includesAimPad: Bool = false
    var isCompact: Bool = false
    /// Extra room at the top. Raised when this view is hosted inside a labelled panel
    /// (Duo Rehearsal), where a surface badge sits over the same corner as the title.
    var topInset: CGFloat = 12

    @State private var showingModes = false

    private let actionColumns = [GridItem(.adaptive(minimum: 74), spacing: 8)]

    var body: some View {
        VStack(spacing: isCompact ? 8 : 12) {
            header

            expressionRow

            LazyVGrid(columns: actionColumns, spacing: 8) {
                ForEach(PuppetAction.allCases) { action in
                    PadButton(symbol: action.symbol,
                              title: action.title,
                              isBusy: engine.activeActions.contains(action)) {
                        engine.send(.perform(action))
                        Haptics.action(action)
                    }
                }
            }

            if includesAimPad {
                AimPad(engine: engine)
                    .frame(minHeight: 96)
            } else {
                Spacer(minLength: 0)
                // The drag-to-look gesture is the one thing nobody finds unprompted,
                // and this band would otherwise be dead space.
                Label("Drag on the stage to make Moppet look around",
                      systemImage: "hand.draw.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.labelDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }

            TalkButton(engine: engine, voice: voice)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.panel)
        .sheet(isPresented: $showingModes) {
            ModeSheet(router: router)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Moppet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.label)

            // Honest, visible proof that several surfaces are being driven at once.
            if engine.rendererCount > 1 {
                Label("\(engine.rendererCount) surfaces", systemImage: "rectangle.on.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent.opacity(0.15)))
            }

            Spacer()

            Button {
                showingModes = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: router.mode.symbol)
                    Text(router.mode.title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.label)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Theme.panelRaised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stage mode: \(router.mode.title)")
            .accessibilityHint("Choose where the puppet performs.")
        }
    }

    private var expressionRow: some View {
        HStack(spacing: 8) {
            ForEach(Expression.allCases) { expression in
                PadButton(symbol: expression.symbol,
                          title: expression.title,
                          isSelected: engine.expression == expression) {
                    engine.send(.setExpression(expression))
                    Haptics.expressionChanged()
                }
            }
        }
    }
}
