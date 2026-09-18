import UIKit

/// Light haptic punctuation on puppet actions.
///
/// Small thing, large effect: a tap that you feel makes the puppet seem to have
/// weight. Honours the app's own sound/haptics setting, and is a silent no-op on
/// hardware without a Taptic Engine.
@MainActor
enum Haptics {

    static var isEnabled = true

    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() {
        guard isEnabled else { return }
        impact.prepare()
        soft.prepare()
    }

    static func action(_ action: PuppetAction) {
        guard isEnabled else { return }
        switch action {
        case .jump, .topple: impact.impactOccurred(intensity: 0.9)
        case .spin:          impact.impactOccurred(intensity: 0.7)
        default:             soft.impactOccurred(intensity: 0.6)
        }
    }

    static func expressionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    static func tick(intensity: Double) {
        guard isEnabled, intensity > 0.05 else { return }
        soft.impactOccurred(intensity: intensity.clamped(to: 0.1...1.0))
    }
}
