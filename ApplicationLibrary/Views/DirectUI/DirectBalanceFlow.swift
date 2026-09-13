import Foundation
import Combine

#if os(iOS)
import RevenueCat

public struct DirectBalanceTransaction: Identifiable, Equatable {
    public enum Kind: String, Codable {
        case topUp = "topup"
        case purchase = "spend"
        case refund = "refund"
        case adjustment = "adjustment"

        public init(serverKind: String) {
            switch serverKind.lowercased() {
            case "topup", "top_up", "credit": self = .topUp
            case "spend", "purchase", "debit": self = .purchase
            case "refund": self = .refund
            default: self = .adjustment
            }
        }
    }

    public let id: String
    public let kind: Kind
    /// Signed USD cents (credit positive, debit negative).
    public let amountUSDCents: Int
    public let title: String
    public let date: Date
    public let productID: String?
    public let transactionID: String?

    public init(
        id: String,
        kind: Kind,
        amountUSDCents: Int,
        title: String,
        date: Date = Date(),
        productID: String? = nil,
        transactionID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.amountUSDCents = amountUSDCents
        self.title = title
        self.date = date
        self.productID = productID
        self.transactionID = transactionID
    }

    public var isDebit: Bool {
        switch kind {
        case .purchase: return true
        case .topUp, .refund, .adjustment: return amountUSDCents < 0
        }
    }

    /// Prefer server title; fall back to a clean Direct label (never raw product ids).
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !trimmed.contains("direct.credits") {
            return trimmed
        }
        return DirectMoney.appleTopUpDisplayTitle(productID: productID, amountUSDCents: amountUSDCents)
    }
}

public struct DirectBalanceSnapshot: Equatable {
    /// USD cents on the account ledger.
    public let usdCents: Int
    public let transactions: [DirectBalanceTransaction]

    public init(usdCents: Int, transactions: [DirectBalanceTransaction] = []) {
        self.usdCents = max(0, usdCents)
        self.transactions = transactions
    }
}

/// Public balance contract. Local hooks replace closures with the real ledger.
///
/// Apple refund / revocation must be handled server-side (App Store Server Notifications /
/// RevenueCat webhooks → ledger `refund`). The client only reconciles uncredited purchases.
public enum DirectBalanceBackend {
    public static var fetchBalance: () async throws -> DirectBalanceSnapshot = {
        throw DirectBalanceError.backendUnavailable
    }

    public static var spendAndGrant: (
        _ amountUSDCents: Int,
        _ title: String,
        _ idempotencyKey: String,
        _ model: VPNConnectionModel
    ) async throws -> DirectBalanceSnapshot = { _, _, _, _ in
        throw DirectBalanceError.backendUnavailable
    }

    /// Credits balance after Apple/RevenueCat confirms a consumable.
    /// `transactionID` is required for idempotent financial credit.
    public static var creditFromRevenueCat: (
        _ productID: String,
        _ appUserID: String,
        _ transactionID: String
    ) async throws -> DirectBalanceSnapshot = { _, _, _ in
        throw DirectBalanceError.backendUnavailable
    }

    /// Optional identity binder before purchase (hooks → RevenueCat.logIn).
    public static var bindRevenueCatIdentity: ((VPNConnectionModel) async throws -> String) = { model in
        let device = UserDefaults.standard.string(forKey: "vpndirect.device.id") ?? UUID().uuidString
        return await MainActor.run {
            DirectRevenueCat.appUserID(
                email: model.directAccountEmail,
                phone: model.directAccountPhone,
                username: model.directAccountUsername,
                deviceID: device
            )
        }
    }
}

public enum DirectBalanceError: LocalizedError, Equatable {
    case backendUnavailable
    case insufficientBalance
    case purchaseProcessing
    case missingTransactionID

    public var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "Баланс временно недоступен. Попробуйте ещё раз."
        case .insufficientBalance:
            return "Недостаточно средств на балансе."
        case .purchaseProcessing:
            return "Покупка подтверждена Apple. Зачисление баланса ещё обрабатывается — средства не пропадут."
        case .missingTransactionID:
            return "Нет идентификатора транзакции Apple — автоматическое зачисление невозможно."
        }
    }
}

@MainActor
public final class DirectBalanceFlow: ObservableObject {
    public enum TopUpSource: Equatable {
        case checkout
        case account
    }

    public enum CreditState: Equatable {
        case idle
        case purchasing
        /// Apple confirmed the payment, but the ledger acknowledgement has not completed yet.
        case creditPending
        case credited
        case failed
    }

    public static let shared = DirectBalanceFlow()

    @Published public private(set) var balanceUSDCents = 0
    @Published public private(set) var transactions: [DirectBalanceTransaction] = []
    @Published public private(set) var isLoadingBalance = false
    @Published public private(set) var isPurchasing = false
    @Published public private(set) var products: [StoreProduct] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var showTopUpSuccess = false
    @Published public private(set) var lastTopUpCents = 0
    @Published public private(set) var topUpSource: TopUpSource = .checkout
    @Published public private(set) var topUpRequiredRubles = 0
    @Published public private(set) var creditState: CreditState = .idle
    @Published public private(set) var lastPurchaseProductID: String?
    @Published public private(set) var lastPurchaseTransactionID: String?

    private var autoContinueTask: Task<Void, Never>?

    private init() {
        syncPublishedPending()
        if hasPendingCredit {
            creditState = .creditPending
        }
    }

    public var balanceDisplay: String { DirectMoney.display(usdCents: balanceUSDCents) }
    public var hasPendingCredit: Bool { DirectPendingAppleCredits.hasPending }
    public var hasPendingAppleCredits: Bool { hasPendingCredit }

    public func balanceCovers(checkoutPriceRubles: Int) -> Bool {
        balanceUSDCents >= DirectMoney.usdCents(fromRubles: checkoutPriceRubles)
    }

    public func shortageRubles(checkoutPriceRubles: Int) -> Int {
        let need = DirectMoney.usdCents(fromRubles: checkoutPriceRubles)
        return DirectMoney.rubles(fromUSDCents: max(0, need - balanceUSDCents))
    }

    public func shortageUSDCents(checkoutPriceRubles: Int) -> Int {
        let need = DirectMoney.usdCents(fromRubles: checkoutPriceRubles)
        return max(0, need - balanceUSDCents)
    }

    public func refresh() async {
        guard !isLoadingBalance else { return }
        isLoadingBalance = true
        errorMessage = nil
        defer {
            isLoadingBalance = false
            syncPublishedPending()
        }
        _ = await DirectMoney.refreshRapiraAskRate()
        // Ledger first — never block UI on RC verify when credit is already booked.
        await resolveStalePendingFromLedger()
        if hasPendingCredit {
            await reconcileUncreditedPurchases()
            await resolveStalePendingFromLedger()
        }
    }

    public func prepareAccountSheetTopUp() {
        topUpSource = .account
        topUpRequiredRubles = 0
        showTopUpSuccess = false
        errorMessage = nil
        Task { @MainActor in
            await resolveStalePendingFromLedger()
            if !hasPendingCredit { creditState = .idle }
        }
        if !hasPendingCredit { creditState = .idle }
    }

    public func payOrTopUp(model: VPNConnectionModel) {
        errorMessage = nil
        let priceRub = max(0, model.checkoutPrice)
        if balanceCovers(checkoutPriceRubles: priceRub) {
            Task { await spendAndGrant(model: model) }
        } else {
            openTopUp(model: model, source: .checkout, requiredRubles: shortageRubles(checkoutPriceRubles: priceRub))
        }
    }

    public func openTopUpFromAccount(model: VPNConnectionModel) {
        openTopUp(model: model, source: .account, requiredRubles: 0)
    }

    public func resetTopUpUIState() {
        showTopUpSuccess = false
        topUpRequiredRubles = 0
        errorMessage = nil
        if !hasPendingCredit { creditState = .idle }
        autoContinueTask?.cancel()
        autoContinueTask = nil
    }

    public func loadProducts() async {
        do {
            DirectRevenueCat.configureIfNeeded()
            products = try await DirectRevenueCat.fetchCreditStoreProducts()
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func purchase(product: StoreProduct, model: VPNConnectionModel) {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        creditState = .purchasing
        lastPurchaseProductID = product.productIdentifier
        lastTopUpCents = DirectMoney.creditCents(forProductID: product.productIdentifier) ?? 0

        Task {
            do {
                DirectRevenueCat.configureIfNeeded()
                let appUserID = try await DirectBalanceBackend.bindRevenueCatIdentity(model)
                try await DirectRevenueCat.logIn(appUserID: appUserID)

                let (_, transactionID) = try await DirectRevenueCat.purchase(product: product)

                // Persist before ledger contact so kill/offline after Apple success can recover.
                DirectPendingAppleCredits.enqueue(
                    DirectPendingAppleCredits.Record(
                        productID: product.productIdentifier,
                        transactionID: transactionID,
                        appUserID: appUserID
                    )
                )
                syncPublishedPending()
                creditState = .creditPending

                do {
                    let snapshot = try await DirectBalanceBackend.creditFromRevenueCat(
                        product.productIdentifier,
                        appUserID,
                        transactionID
                    )
                    DirectPendingAppleCredits.remove(transactionID: transactionID)
                    syncPublishedPending()
                    apply(snapshot)
                    creditState = .credited
                    errorMessage = nil
                    showTopUpSuccess = true
                    isPurchasing = false
                    scheduleAutoContinueIfNeeded(model: model)
                } catch {
                    DirectPendingAppleCredits.updateError(
                        transactionID: transactionID,
                        message: error.localizedDescription
                    )
                    // Apple already confirmed — never present as a failed purchase.
                    errorMessage = DirectBalanceError.purchaseProcessing.errorDescription
                    creditState = .creditPending
                    isPurchasing = false
                    Task {
                        await resolveStalePendingFromLedger()
                        if hasPendingCredit {
                            await reconcileUncreditedPurchases()
                        }
                    }
                }
            } catch {
                isPurchasing = false
                if let rc = error as? DirectRevenueCatError, rc == .cancelled {
                    errorMessage = nil
                    creditState = hasPendingCredit ? .creditPending : .idle
                } else if let rc = error as? DirectRevenueCatError, rc == .missingTransactionID {
                    errorMessage = DirectBalanceError.purchaseProcessing.errorDescription
                    creditState = .creditPending
                    Task {
                        await resolveStalePendingFromLedger()
                        if hasPendingCredit {
                            await reconcileUncreditedPurchases()
                        }
                        if !hasPendingCredit, balanceUSDCents > 0 {
                            creditState = .credited
                            errorMessage = nil
                            showTopUpSuccess = true
                            scheduleAutoContinueIfNeeded(model: model)
                        }
                    }
                } else {
                    errorMessage = error.localizedDescription
                    creditState = .failed
                }
            }
        }
    }

    /// Retry the ledger acknowledgement for already-confirmed Apple transaction(s).
    public func retryPendingCredit() {
        guard hasPendingCredit, !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        creditState = .creditPending
        Task {
            // 1) Instant path: balance/history already has this Apple tx.
            await resolveStalePendingFromLedger()
            // 2) Only then ask server to credit remaining pending rows.
            if hasPendingCredit {
                await reconcileUncreditedPurchases()
                await resolveStalePendingFromLedger()
            }
            isPurchasing = false
            syncPublishedPending()
            if !hasPendingCredit {
                creditState = .credited
                errorMessage = nil
                showTopUpSuccess = true
            } else {
                errorMessage = "Средства уже подтверждены Apple, но сервер пока не завершил зачисление. Попробуйте ещё раз позже."
                creditState = .creditPending
            }
        }
    }

    /// Reconcile confirmed Apple purchases after app relaunch / foreground.
    public func reconcilePendingCredit() {
        guard hasPendingCredit, !isPurchasing else { return }
        retryPendingCredit()
    }

    public func dismissTopUpSuccessAndReturn(model: VPNConnectionModel) {
        autoContinueTask?.cancel()
        autoContinueTask = nil
        showTopUpSuccess = false
        topUpRequiredRubles = 0
        creditState = hasPendingCredit ? .creditPending : .idle
        errorMessage = nil
        Task { await refresh() }
        switch topUpSource {
        case .checkout:
            if balanceCovers(checkoutPriceRubles: model.checkoutPrice) {
                Task { await spendAndGrant(model: model) }
            } else {
                model.openDetail(.payment)
            }
        case .account:
            model.openDetail(.balanceAccount)
        }
    }

    public func dismissTopUpSuccessAndReturnToCheckout(model: VPNConnectionModel) {
        dismissTopUpSuccessAndReturn(model: model)
    }

    public func finishTopUp(model: VPNConnectionModel) {
        dismissTopUpSuccessAndReturn(model: model)
    }

    public func cancelTopUp(model: VPNConnectionModel) {
        autoContinueTask?.cancel()
        autoContinueTask = nil
        errorMessage = nil
        showTopUpSuccess = false
        topUpRequiredRubles = 0
        if !hasPendingCredit { creditState = .idle }
        switch topUpSource {
        case .checkout:
            model.openDetail(.payment)
        case .account:
            model.openDetail(.balanceAccount)
        }
    }

    /// App launch / foreground: push any Apple-confirmed purchases into the ledger.
    public func reconcileUncreditedPurchases() async {
        DirectRevenueCat.configureIfNeeded()
        await resolveStalePendingFromLedger()

        var candidates = DirectPendingAppleCredits.all()
        if DirectRevenueCat.publicAPIKey.isEmpty == false {
            do {
                let info = try await DirectRevenueCat.customerInfo()
                let fromRC = DirectRevenueCat.creditPurchases(from: info)
                for row in fromRC
                where !DirectPendingAppleCredits.isCredited(transactionID: row.transactionID)
                    && !candidates.contains(where: { $0.transactionID == row.transactionID }) {
                    DirectPendingAppleCredits.enqueue(row)
                    candidates.append(row)
                }
                // Drop anything RC still lists but ledger already has.
                await resolveStalePendingFromLedger()
                candidates = DirectPendingAppleCredits.all()
            } catch {
                // Offline / RC not configured — still try local pending queue.
            }
        }

        syncPublishedPending()
        guard !candidates.isEmpty else {
            if creditState == .creditPending {
                creditState = .idle
                errorMessage = nil
            }
            return
        }

        if creditState != .purchasing {
            creditState = .creditPending
        }

        for record in candidates {
            do {
                let snapshot = try await DirectBalanceBackend.creditFromRevenueCat(
                    record.productID,
                    record.appUserID,
                    record.transactionID
                )
                DirectPendingAppleCredits.remove(transactionID: record.transactionID)
                apply(snapshot)
                lastTopUpCents = DirectMoney.creditCents(forProductID: record.productID) ?? lastTopUpCents
            } catch {
                DirectPendingAppleCredits.updateError(
                    transactionID: record.transactionID,
                    message: error.localizedDescription
                )
            }
        }

        await resolveStalePendingFromLedger()
        syncPublishedPending()
        if !hasPendingCredit {
            if creditState == .creditPending || creditState == .purchasing {
                creditState = .credited
                errorMessage = nil
                showTopUpSuccess = true
            }
        } else if creditState != .purchasing {
            creditState = .creditPending
            errorMessage = DirectBalanceError.purchaseProcessing.errorDescription
        }
    }

    /// Pull ledger and drop local pending rows that are already booked.
    @discardableResult
    public func resolveStalePendingFromLedger() async -> Bool {
        do {
            let snapshot = try await DirectBalanceBackend.fetchBalance()
            apply(snapshot)
            clearPendingAlreadyOnLedger(using: snapshot)
            syncPublishedPending()
            if !hasPendingCredit {
                if creditState == .creditPending {
                    creditState = .idle
                }
                errorMessage = nil
                return true
            }
        } catch {
            // keep pending
        }
        return !hasPendingCredit
    }

    /// Drop local pending rows that the ledger already acknowledges.
    private func clearPendingAlreadyOnLedger(using snapshot: DirectBalanceSnapshot) {
        let pending = DirectPendingAppleCredits.all()
        guard !pending.isEmpty else { return }
        for record in pending {
            let tx = record.transactionID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tx.isEmpty else { continue }
            let cents = DirectMoney.creditCents(forProductID: record.productID)
            let matched = snapshot.transactions.contains { row in
                if let rowTx = row.transactionID?.trimmingCharacters(in: .whitespacesAndNewlines), rowTx == tx {
                    return true
                }
                let id = row.id
                if id == tx || id == "apple:\(tx)" { return true }
                if id.hasSuffix(":\(tx)") { return true }
                if id.contains(tx) { return true }
                // Same pack already on ledger (covers admin/manual credit with alternate idempotency key).
                if row.kind == .topUp,
                   let cents,
                   abs(row.amountUSDCents) == cents,
                   (row.productID == record.productID || row.productID == nil) {
                    return true
                }
                return false
            }
            if matched {
                DirectPendingAppleCredits.remove(transactionID: record.transactionID)
            }
        }
    }

    private func scheduleAutoContinueIfNeeded(model: VPNConnectionModel) {
        guard topUpSource == .checkout else { return }
        autoContinueTask?.cancel()
        autoContinueTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled, showTopUpSuccess else { return }
            finishTopUp(model: model)
        }
    }

    private func openTopUp(model: VPNConnectionModel, source: TopUpSource, requiredRubles: Int) {
        topUpSource = source
        topUpRequiredRubles = max(0, requiredRubles)
        showTopUpSuccess = false
        errorMessage = nil
        if !hasPendingCredit { creditState = .idle }
        model.openDetail(.balanceTopUp)
        Task { await loadProducts() }
    }

    private func spendAndGrant(model: VPNConnectionModel) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        model.openDetail(.paymentProcessing)
        let key = "balance-\(UUID().uuidString)"
        let amountCents = DirectMoney.usdCents(fromRubles: model.checkoutPrice)
        do {
            let snapshot = try await DirectBalanceBackend.spendAndGrant(
                amountCents,
                model.checkoutTitle,
                key,
                model
            )
            apply(snapshot)
            isPurchasing = false
        } catch {
            isPurchasing = false
            if let direct = error as? DirectBalanceError, direct == .insufficientBalance {
                errorMessage = direct.errorDescription
                openTopUp(
                    model: model,
                    source: .checkout,
                    requiredRubles: shortageRubles(checkoutPriceRubles: model.checkoutPrice)
                )
            } else {
                errorMessage = error.localizedDescription
                model.paymentErrorMessage = error.localizedDescription
                model.openDetail(.paymentError)
            }
        }
    }

    private func syncPublishedPending() {
        let newest = DirectPendingAppleCredits.all().sorted { $0.purchasedAt > $1.purchasedAt }.first
        lastPurchaseProductID = newest?.productID
        lastPurchaseTransactionID = newest?.transactionID
    }

    private func apply(_ snapshot: DirectBalanceSnapshot) {
        balanceUSDCents = snapshot.usdCents
        transactions = snapshot.transactions
    }
}

#endif
