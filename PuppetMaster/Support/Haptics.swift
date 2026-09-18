import UIKit

/// Light haptic punctuation on puppet actions.
///
/// Small thing, large effect: a tap that you feel makes the puppet seem to have
/// weight. Honours the app's own sound/haptics setting, and is a silent no-op on
/// hardware without a Taptic Engine.
@MainActor
enum Haptics {

    static var isEnabled = true

    private static let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() {
        guard isEnabled else { return }
        impactGenerator.prepare()
        soft.prepare()
    }

    static func action(_ action: PuppetAction) {
        guard isEnabled else { return }
        switch action {
        case .jump, .topple: impactGenerator.impactOccurred(intensity: 0.9)
        case .spin:          impactGenerator.impactOccurred(intensity: 0.7)
        default:             soft.impactOccurred(intensity: 0.6)
        }
    }

    static func expressionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    /// Fired on an animation beat rather than a button press — the moment a landing
    /// actually lands.
    static func impact(_ intensity: Double) {
        guard isEnabled else { return }
        impactGenerator.impactOccurred(intensity: intensity.clamped(to: 0.1...1.0))
    }

    static func tick(intensity: Double) {
        guard isEnabled, intensity > 0.05 else { return }
        soft.impactOccurred(intensity: intensity.clamped(to: 0.1...1.0))
    }
}
