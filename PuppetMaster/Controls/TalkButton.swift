import SwiftUI

/// Press and hold to give the puppet your voice.
///
/// The microphone is live only while the button is held — visible, honest, and easier
/// to explain than a toggle. The fill is a real level meter, so you can see that the
/// app is hearing you before you look up at the puppet.
struct TalkButton: View {

    let engine: PuppetEngine
    @Bindable var voice: VoiceInput

    @State private var isPressed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.panelRaised)

                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.accent.opacity(0.85))
                    .frame(width: max(0, geometry.size.width * voice.displayLevel))
                    .animation(.linear(duration: 0.05), value: voice.displayLevel)

                HStack(spacing: 9) {
                    Image(systemName: voice.talkButtonSymbol)
                        .font(.system(size: 20, weight: .semibold))
                    Text(voice.talkButtonTitle)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Theme.label)
                .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: isPressed ? 2.5 : 0)
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        Haptics.tick(intensity: 0.5)
                        Task { await voice.beginTalking() }
                    }
                    .onEnded { _ in
                        isPressed = false
                        voice.endTalking()
                    }
            )
        }
        .frame(height: Theme.touchTarget)
        .accessibilityElement()
        .accessibilityLabel(voice.talkButtonTitle)
        .accessibilityHint("Touch and hold. Moppet's mouth follows your voice.")
    }
}
