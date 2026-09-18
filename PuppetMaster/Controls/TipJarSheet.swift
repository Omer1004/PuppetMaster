import StoreKit
import SwiftUI

/// The tip jar, as a sheet you have to go looking for.
///
/// It sells nothing: no feature is gated, no tier is better, and the app never mentions
/// it again once you have tipped. The tone matters more than the code here — a toy that
/// children use should not learn to ask them for money.
struct TipJarSheet: View {

    let tipJar: TipJar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if tipJar.didThank {
                    thanks
                } else {
                    switch tipJar.state {
                    case .idle, .loading: loading
                    case .ready:          jar
                    case .unavailable:    unavailable
                    }
                }
            }
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .task { await tipJar.load() }
    }

    private var jar: some View {
        List {
            Section {
                ForEach(tipJar.tips, id: \.id) { tip in
                    Button {
                        Task { await tipJar.purchase(tip) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tip.displayName)
                                    .font(.system(.callout).weight(.semibold))
                                if !tip.description.isEmpty {
                                    Text(tip.description)
                                        .font(.system(.caption))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(tip.displayPrice)
                                .font(.system(.subheadline).weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(tipJar.isPurchasing)
                }
            } header: {
                Text("If you have enjoyed this")
            } footer: {
                Text("""
                    A tip unlocks nothing — every character, backdrop and move is already \
                    yours. It just pays for the time that goes into the next one.
                    """)
            }
        }
    }

    private var thanks: some View {
        ContentUnavailableView {
            Label("Thank you", systemImage: "heart.fill")
                .foregroundStyle(Theme.accent)
        } description: {
            Text("That genuinely helps. Now go and put on a show.")
        }
    }

    private var loading: some View {
        ProgressView().controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shown when the store has nothing for us. Being straight about it beats three
    /// buttons that do nothing when tapped.
    private var unavailable: some View {
        ContentUnavailableView {
            Label("Not available right now", systemImage: "wifi.exclamationmark")
        } description: {
            Text("The tip jar could not be reached. No harm done — try again later.")
        }
    }
}
