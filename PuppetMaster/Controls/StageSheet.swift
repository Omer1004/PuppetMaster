import SwiftUI

/// Where the puppet performs, and what it performs in front of.
///
/// Unavailable modes are shown and explained rather than hidden — a missing option reads
/// as a bug, and Duo in particular is worth telling people about even while it is
/// waiting on hardware.
struct StageSheet: View {

    let router: StageRouter
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Surfaces") {
                    ForEach(router.allModes) { mode in
                        modeRow(for: mode)
                    }
                }

                Section {
                    ForEach(BackdropLibrary.all) { backdrop in
                        backdropRow(for: backdrop)
                    }
                } header: {
                    Text("Backdrop")
                } footer: {
                    Text("""
                        The stage and the controls are separate surfaces driven by one \
                        engine. Duo Rehearsal shows both at once on this phone — it runs \
                        exactly the code a real two-screen device would.
                        """)
                }
            }
            .navigationTitle("Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func modeRow(for mode: PresentationMode) -> some View {
        let available = router.isAvailable(mode)

        Button {
            router.select(mode)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 20))
                    .frame(width: 30)
                    .foregroundStyle(available ? Theme.accent : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(router.unavailableReason(for: mode) ?? mode.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if router.mode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.55)
    }

    private func backdropRow(for backdrop: Backdrop) -> some View {
        Button {
            environment.selectBackdrop(backdrop)
        } label: {
            HStack(spacing: 14) {
                // A slice of the actual gradient, so the choice is visible rather than
                // described.
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(backdrop.skyTop.uiColor), Color(backdrop.skyBottom.uiColor)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 30, height: 30)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(backdrop.floor.uiColor))
                            .frame(height: 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Label(backdrop.name, systemImage: backdrop.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .labelStyle(.titleOnly)

                Spacer()

                if environment.backdrop.id == backdrop.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
