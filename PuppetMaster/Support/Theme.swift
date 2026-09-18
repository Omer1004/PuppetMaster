import SwiftUI

/// Small shared vocabulary for the control surface.
///
/// The controls are deliberately quiet: warm neutrals, one accent, generous targets.
/// Everything colourful on screen should be the puppet.
enum Theme {
    static let accent = Color(red: 0.95, green: 0.45, blue: 0.20)
    static let panel = Color(red: 0.14, green: 0.13, blue: 0.16)
    static let panelRaised = Color(red: 0.21, green: 0.20, blue: 0.24)
    static let panelSelected = Color(red: 0.95, green: 0.45, blue: 0.20)
    static let label = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let labelDim = Color(red: 0.96, green: 0.94, blue: 0.91).opacity(0.55)

    /// Minimum comfortable target. Kept generous because the people using this are
    /// often holding a phone in one hand and a child in the other.
    static let touchTarget: CGFloat = 56
    static let corner: CGFloat = 18
}

/// A small pill used for the character and stage-mode buttons in the header.
struct HeaderChip: View {
    let symbol: String
    let title: String
    var tint: Color = Theme.label
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.panelRaised))
        }
        .buttonStyle(.plain)
    }
}

/// A control-panel button: large, tactile, and obvious whether it is on.
struct PadButton: View {
    let symbol: String
    let title: String
    var isSelected: Bool = false
    var isBusy: Bool = false
    /// Shrunk when the controls are sharing a screen with the stage.
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 3 : 5) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 18 : 21, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 52 : Theme.touchTarget + 8)
            .foregroundStyle(isSelected ? Color.black : Theme.label)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(isSelected ? Theme.panelSelected : Theme.panelRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(isBusy ? 0.9 : 0), lineWidth: 2)
            )
            .scaleEffect(isBusy ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isBusy)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
