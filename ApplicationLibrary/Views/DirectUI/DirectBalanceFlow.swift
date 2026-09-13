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
            case "topup", "top_up", "credit":
                self = .topUp
            case "spend", "purchase", "debit":
                self = .purchase
            case "refund":
                self = .refund
            default:
                self = .adjustment
            }
        }
    }

    public let id: String
    public let kind: Kind
    /// Signed USD cents (credit positive, debit negative).
    public let amountUSDCents: Int
    public let title: String
    public let date: Date

    public init(id: String, kind: Kind, amountUSDCents: Int, title: String, date: Date = Date()) {
        self.id = id
        self.kind = kind
        self.amountUSDCents = amountUSDCents
        self.title = title
        self.date = date
    }

    public var isDebit: Bool {
        switch kind {
        case .purchase: return true
        case .topUp, .refund, .adjustment: return amountUSDCents < 0
        }
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
public enum DirectBalanceBackend {
    public static var fetchBalance: () async throws -> DirectBalanceSnapshot = {
        throw DirectBalanceError.backendUnavailable
    }

    /// Atomically spends USD cents and grants the selected subscription/add-on.
    public static var spendAndGrant: (
        _ amountUSDCents: Int,
        _ title: String,
        _ idempotencyKey: String,
        _ model: VPNConnectionModel
    ) async throws -> DirectBalanceSnapshot = { _, _, _, _ in
        throw DirectBalanceError.backendUnavailable
    }

    /// Credits balance after RevenueCat confirms a consumable.
    public static var creditFromRevenueCat: (
        _ productID: String,
        _ appUserID: String,
        _ transactionID: String?
    ) async throws -> DirectBalanceSnapshot = { _, _, _ in
        throw DirectBalanceError.backendUnavailable
    }
}

public enum DirectBalanceError: LocalizedError, Equatable {
    case backendUnavailable
    case insufficientBalance
    case purchaseProcessing

    public var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "Баланс временно недоступен. Попробуйте ещё раз."
        case .insufficientBalance:
            return "Недостаточно средств на балансе."
        case .purchaseProcessing:
            return "Покупка обрабатывается. Баланс обновится автоматически."
        }
    }
}

@MainActor
public final class DirectBalanceFlow: ObservableObject {
    public enum TopUpSource: Equatable {
        /// Opened from payment method when checkout balance is short.
        case checkout
        /// Opened from Profile → Balance (standalone top-up).
        case account
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
    /// RUB shortage when topping up from checkout; 0 for standalone profile top-up.
    @Published public private(set) var topUpRequiredRubles = 0

    private init() {}

    public var balanceDisplay: String { DirectMoney.display(usdCents: balanceUSDCents) }

    public func balanceCovers(checkoutPriceRubles: Int) -> Bool {
        balanceUSDCents >= DirectMoney.usdCents(fromRubles: checkoutPriceRubles)
    }

    public func shortageRubles(checkoutPriceRubles: Int) -> Int {
        let need = DirectMoney.usdCents(fromRubles: checkoutPriceRubles)
        let shortCents = max(0, need - balanceUSDCents)
        return DirectMoney.rubles(fromUSDCents: shortCents)
    }

    public func refresh() async {
        guard !isLoadingBalance else { return }
        isLoadingBalance = true
        errorMessage = nil
        defer { isLoadingBalance = false }
        do {
            let snapshot = try await DirectBalanceBackend.fetchBalance()
            apply(snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
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

    /// Prepare standalone Apple top-up presented as a sheet over the balance account.
    public func prepareAccountSheetTopUp() {
        topUpSource = .account
        topUpRequiredRubles = 0
        showTopUpSuccess = false
        errorMessage = nil
    }

    public func resetTopUpUIState() {
        showTopUpSuccess = false
        topUpRequiredRubles = 0
        errorMessage = nil
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

    public func purchase(product: StoreProduct) {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        lastTopUpCents = DirectMoney.creditCents(forProductID: product.productIdentifier) ?? 0

        Task {
            do {
                DirectRevenueCat.configureIfNeeded()
                let (info, transactionID) = try await DirectRevenueCat.purchase(product: product)
                let snapshot = try await DirectBalanceBackend.creditFromRevenueCat(
                    product.productIdentifier,
                    info.originalAppUserId,
                    transactionID
                )
                apply(snapshot)
                showTopUpSuccess = true
                isPurchasing = false
            } catch {
                isPurchasing = false
                if let rc = error as? DirectRevenueCatError, rc == .cancelled {
                    errorMessage = nil
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func dismissTopUpSuccessAndReturn(model: VPNConnectionModel) {
        showTopUpSuccess = false
        topUpRequiredRubles = 0
        Task { await refresh() }
        switch topUpSource {
        case .checkout:
            model.openDetail(.payment)
        case .account:
            // Stay on / return to balance account + history.
            model.openDetail(.balanceAccount)
        }
    }

    /// Kept for callers that still use the checkout-specific name.
    public func dismissTopUpSuccessAndReturnToCheckout(model: VPNConnectionModel) {
        dismissTopUpSuccessAndReturn(model: model)
    }

    public func finishTopUp(model: VPNConnectionModel) {
        dismissTopUpSuccessAndReturn(model: model)
    }

    public func cancelTopUp(model: VPNConnectionModel) {
        errorMessage = nil
        showTopUpSuccess = false
        topUpRequiredRubles = 0
        switch topUpSource {
        case .checkout:
            model.openDetail(.payment)
        case .account:
            model.openDetail(.balanceAccount)
        }
    }

    private func openTopUp(model: VPNConnectionModel, source: TopUpSource, requiredRubles: Int) {
        topUpSource = source
        topUpRequiredRubles = max(0, requiredRubles)
        showTopUpSuccess = false
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

    private func apply(_ snapshot: DirectBalanceSnapshot) {
        balanceUSDCents = snapshot.usdCents
        transactions = snapshot.transactions
    }
}

#endif
