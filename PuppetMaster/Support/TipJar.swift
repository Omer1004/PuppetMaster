import Foundation
import Observation
import OSLog
import StoreKit

/// A tip jar: three consumable purchases that buy nothing.
///
/// Deliberately not a paywall and deliberately not a subscription. Nothing in the app is
/// withheld behind it, no feature appears when you tip, and it is never shown
/// unprompted. That is a product decision, not a technical one — see `PRD.md` §5.
///
/// Consumables rather than non-consumables, because a tip should be repeatable and there
/// is nothing to restore. That also keeps this type small: no entitlement to track, no
/// receipt to persist, nothing to sync. StoreKit 2 verifies each transaction on device
/// and we finish it.
///
/// **Before this can work:** the three product identifiers below must exist in App Store
/// Connect as consumables. Until then `Product.products(for:)` returns an empty array and
/// the sheet says so honestly rather than showing dead buttons.
@MainActor
@Observable
final class TipJar {

    enum State: Equatable {
        case idle
        case loading
        case ready
        /// Loaded, but the store returned nothing — most often unconfigured products,
        /// no network, or a device with purchases disabled.
        case unavailable
    }

    private(set) var state: State = .idle
    /// Sorted cheapest first. Empty until `load()` succeeds.
    private(set) var tips: [Product] = []
    /// Set after a successful purchase so the sheet can say thank you and stop selling.
    private(set) var didThank = false
    private(set) var isPurchasing = false

    private var updates: Task<Void, Never>?
    private let log = Logger(subsystem: "com.omerwm.puppetmaster", category: "tips")

    /// Must match App Store Connect exactly. Grouped under `tip.` so a later
    /// non-consumable (a cast pack, say) cannot be mistaken for one of these.
    static let productIDs = [
        "com.omerwm.puppetmaster.tip.small",
        "com.omerwm.puppetmaster.tip.medium",
        "com.omerwm.puppetmaster.tip.large",
    ]

    init() {
        // A purchase can complete long after the sheet is gone — Ask to Buy, or an
        // interrupted payment. An unfinished transaction is retried by the system
        // forever, so the listener starts with the app and outlives any view.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.finish(update)
            }
        }
    }

    // Intentionally no `deinit`: this lives on ``AppEnvironment``, which is a
    // process-lifetime singleton, so a deallocator would never run. Under Swift 6 strict
    // concurrency a nonisolated deallocator cannot touch main-actor state anyway. The
    // task holds `self` weakly, so nothing here keeps anything alive.

    // MARK: Loading

    func load() async {
        guard state != .loading, tips.isEmpty else { return }
        state = .loading
        do {
            let products = try await Product.products(for: Self.productIDs)
            tips = products.sorted { $0.price < $1.price }
            state = tips.isEmpty ? .unavailable : .ready
            if tips.isEmpty {
                log.notice("No tip products returned — are they configured in App Store Connect?")
            }
        } catch {
            log.error("Could not load tips: \(error.localizedDescription)")
            state = .unavailable
        }
    }

    // MARK: Buying

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await finish(verification)
            case .userCancelled, .pending:
                // Neither is an error. Pending means a parent has to approve it, and the
                // transaction listener will pick it up whenever that happens.
                break
            @unknown default:
                break
            }
        } catch {
            log.error("Tip did not go through: \(error.localizedDescription)")
        }
    }

    /// Verify, thank, and finish. A consumable that is never finished is offered back to
    /// the app on every launch, forever.
    private func finish(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            // Finished, not just ignored. An unfinished transaction comes back through
            // `Transaction.updates` on every single launch — so silently dropping this
            // one leaves the user with a permanently stuck tip. Nothing is unlocked
            // either way: a tip buys gratitude, so there is nothing to withhold.
            if case .unverified(let transaction, let error) = result {
                log.error("Finishing an unverified transaction: \(error.localizedDescription)")
                await transaction.finish()
            }
            return
        }
        guard Self.productIDs.contains(transaction.productID) else {
            await transaction.finish()
            return
        }
        didThank = true
        await transaction.finish()
    }
}
