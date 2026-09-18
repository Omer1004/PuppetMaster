import SwiftUI

/// Where the puppet performs.
///
/// Unavailable modes are shown and explained rather than hidden — a missing option
/// reads as a bug, and Duo in particular is worth telling people about even while it
/// is waiting on hardware.
struct ModeSheet: View {

    let router: StageRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(router.allModes) { mode in
                        row(for: mode)
                    }
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
    private func row(for mode: PresentationMode) -> some View {
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
}
