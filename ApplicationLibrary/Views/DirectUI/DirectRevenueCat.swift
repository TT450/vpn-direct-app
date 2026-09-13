import Foundation

#if os(iOS)
import RevenueCat

/// RevenueCat wrapper for VPN Direct **consumable** credit top-ups.
/// Balance truth lives on the Direct ledger — not in an RC entitlement.
public enum DirectRevenueCat {
    public static let offeringIdentifier = "credits"
    /// Offering-only label. Do **not** treat this entitlement as balance.
    public static let offeringEntitlementHint = "credits"

    /// App Store / RevenueCat product IDs (must match ASC + RC catalog).
    public static let creditProductIDs: [String] = [
        "direct.credits.4.99",
        "direct.credits.9.99",
        "direct.credits.19.99",
        "direct.credits.49.99",
        "direct.credits.99.99",
        "direct.credits.199.99",
    ]

    /// USD face values for packs (1:1 with App Store face value / ledger credit).
    public static let creditUSDByProductID: [String: Decimal] = [
        "direct.credits.4.99": 4.99,
        "direct.credits.9.99": 9.99,
        "direct.credits.19.99": 19.99,
        "direct.credits.49.99": 49.99,
        "direct.credits.99.99": 99.99,
        "direct.credits.199.99": 199.99,
    ]

    /// App Store public SDK key. Empty on GitHub; local hooks fill it at launch.
    public static var publicAPIKey = ""

    private static var didConfigure = false

    public static func configureIfNeeded() {
        guard !didConfigure else { return }
        guard !publicAPIKey.isEmpty else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: publicAPIKey)
        didConfigure = true
    }

    public static func logIn(appUserID: String) async throws {
        configureIfNeeded()
        guard didConfigure else { throw DirectRevenueCatError.notConfigured }
        _ = try await Purchases.shared.logIn(appUserID)
    }

    public static func logOut() async throws {
        guard didConfigure else { return }
        _ = try await Purchases.shared.logOut()
    }

    public static func customerInfo() async throws -> CustomerInfo {
        configureIfNeeded()
        guard didConfigure else { throw DirectRevenueCatError.notConfigured }
        return try await Purchases.shared.customerInfo()
    }

    public static func fetchCreditPackages() async throws -> [Package] {
        configureIfNeeded()
        let offerings = try await Purchases.shared.offerings()
        if let offering = offerings.offering(identifier: offeringIdentifier), !offering.availablePackages.isEmpty {
            return offering.availablePackages.sorted { lhs, rhs in
                lhs.storeProduct.price < rhs.storeProduct.price
            }
        }
        return []
    }

    public static func fetchCreditStoreProducts() async throws -> [StoreProduct] {
        configureIfNeeded()
        let packages = try await fetchCreditPackages()
        if !packages.isEmpty {
            return packages.map(\.storeProduct)
        }
        return try await Purchases.shared.products(creditProductIDs)
            .sorted { $0.price < $1.price }
    }

    /// Stable Direct↔RevenueCat identity for the signed-in account.
    public static func appUserID(email: String?, phone: String?, username: String?, deviceID: String) -> String {
        if let email, !email.isEmpty { return "email:\(email.lowercased())" }
        if let phone, !phone.isEmpty { return "phone:\(phone)" }
        if let username, !username.isEmpty { return "user:\(username)" }
        return "device:\(deviceID)"
    }

    public static func creditUSD(forProductID productID: String) -> Decimal? {
        creditUSDByProductID[productID]
    }

    /// Sort packs so the cheapest covering USD credit comes first (currency-aware).
    public static func sortedProducts(
        _ products: [StoreProduct],
        coveringUSDCents neededCents: Int
    ) -> [StoreProduct] {
        let neededUSD = Decimal(max(0, neededCents)) / Decimal(100)
        func covers(_ product: StoreProduct) -> Bool {
            if let usd = creditUSD(forProductID: product.productIdentifier) {
                return usd >= neededUSD
            }
            if product.currencyCode?.uppercased() == "USD" {
                return product.price >= neededUSD
            }
            return false
        }
        func usdFace(_ product: StoreProduct) -> Decimal {
            creditUSD(forProductID: product.productIdentifier)
                ?? (product.currencyCode?.uppercased() == "USD" ? product.price : product.price)
        }
        let covering = products.filter(covers).sorted { usdFace($0) < usdFace($1) }
        let rest = products.filter { !covers($0) }.sorted { usdFace($0) < usdFace($1) }
        if covering.isEmpty { return products.sorted { usdFace($0) < usdFace($1) } }
        return covering + rest
    }

    public static func isRecommended(
        _ product: StoreProduct,
        among products: [StoreProduct],
        coveringUSDCents neededCents: Int
    ) -> Bool {
        guard neededCents > 0 else { return false }
        let sorted = sortedProducts(products, coveringUSDCents: neededCents)
        return sorted.first?.productIdentifier == product.productIdentifier
            && (creditUSD(forProductID: product.productIdentifier) ?? 0)
            >= (Decimal(neededCents) / Decimal(100))
    }

    public static func purchase(package: Package) async throws -> (CustomerInfo, String) {
        configureIfNeeded()
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            throw DirectRevenueCatError.cancelled
        }
        guard let tx = result.transaction?.transactionIdentifier, !tx.isEmpty else {
            throw DirectRevenueCatError.missingTransactionID
        }
        return (result.customerInfo, tx)
    }

    public static func purchase(product: StoreProduct) async throws -> (CustomerInfo, String) {
        configureIfNeeded()
        let result = try await Purchases.shared.purchase(product: product)
        if result.userCancelled {
            throw DirectRevenueCatError.cancelled
        }
        guard let tx = result.transaction?.transactionIdentifier, !tx.isEmpty else {
            throw DirectRevenueCatError.missingTransactionID
        }
        return (result.customerInfo, tx)
    }

    /// Consumable credit purchases known to RevenueCat for this customer.
    public static func creditPurchases(from info: CustomerInfo) -> [DirectPendingAppleCredits.Record] {
        var out: [DirectPendingAppleCredits.Record] = []
        let appUser = info.originalAppUserId
        for tx in info.nonSubscriptions {
            let productID = tx.productIdentifier
            guard creditProductIDs.contains(productID) else { continue }
            let id = tx.transactionIdentifier
            guard !id.isEmpty else { continue }
            out.append(
                DirectPendingAppleCredits.Record(
                    productID: productID,
                    transactionID: id,
                    appUserID: appUser,
                    purchasedAt: tx.purchaseDate
                )
            )
        }
        return out.sorted { $0.purchasedAt > $1.purchasedAt }
    }
}

public enum DirectRevenueCatError: LocalizedError, Equatable {
    case cancelled
    case productsUnavailable
    case notConfigured
    case missingTransactionID

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Покупка отменена"
        case .productsUnavailable:
            return "Пакеты пополнения пока недоступны в App Store. Дождитесь Ready to Submit / Sandbox."
        case .notConfigured:
            return "RevenueCat не настроен"
        case .missingTransactionID:
            return "Apple не вернул идентификатор транзакции. Баланс не зачислен — покупка будет проверена при следующем запуске."
        }
    }
}

#endif
