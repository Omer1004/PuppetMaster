import SwiftUI

/// Who performs.
///
/// Characters are data, so this list is generated from ``CharacterLibrary`` — adding a
/// cast member never touches this file.
struct CastSheet: View {

    let engine: PuppetEngine
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CharacterLibrary.all) { character in
                        row(for: character)
                    }
                } footer: {
                    Text("""
                        Every character uses the same rig and the same moves — what \
                        changes is the shape and the timing. Pip breathes twice as fast \
                        as Bramble, which is most of why they feel like different \
                        creatures.
                        """)
                }
            }
            .navigationTitle("Cast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(for character: CharacterDescriptor) -> some View {
        Button {
            // Through the environment, not straight to the engine: the environment is
            // what remembers the choice for next launch.
            environment.selectCharacter(id: character.id)
            Haptics.expressionChanged()
            dismiss()
        } label: {
            HStack(spacing: 14) {
                CharacterSwatch(character: character)

                VStack(alignment: .leading, spacing: 3) {
                    Text(character.name)
                        .font(.system(size: 16, weight: .semibold))
                    Text(character.tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if engine.character.id == character.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A quick read of a character's palette and silhouette, without spinning up a scene.
private struct CharacterSwatch: View {
    let character: CharacterDescriptor

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(character.palette.fur.uiColor))
            Circle()
                .fill(Color(character.palette.belly.uiColor))
                .frame(width: 16, height: 20)
                .offset(y: 5)
            Circle()
                .fill(Color(character.palette.accent.uiColor))
                .frame(width: 10, height: 10)
                .offset(x: 11, y: -12)
        }
        .frame(width: 38, height: 38)
        .overlay(Circle().strokeBorder(Color(character.palette.outline.uiColor), lineWidth: 2))
    }
}
