import Foundation

#if os(iOS)
import RevenueCat

/// RevenueCat wrapper for VPN Direct credit top-ups (consumable IAP).
/// Public SDK key is safe in the client; never put the secret API key here.
public enum DirectRevenueCat {
    public static let offeringIdentifier = "credits"
    public static let entitlementIdentifier = "credits"

    /// App Store / RevenueCat product IDs (must match ASC + RC catalog).
    public static let creditProductIDs: [String] = [
        "direct.credits.4.99",
        "direct.credits.9.99",
        "direct.credits.19.99",
        "direct.credits.49.99",
        "direct.credits.99.99",
        "direct.credits.199.99",
    ]

    /// USD face values for packs (1 credit ≈ $1) when StoreKit currency differs from checkout.
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
        _ = try await Purchases.shared.logIn(appUserID)
    }

    public static func logOut() async throws {
        guard didConfigure else { return }
        _ = try await Purchases.shared.logOut()
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

    /// Picks the cheapest pack that covers `amount` in the product's storefront currency when possible.
    public static func packageCovering(amount: Decimal, currencyCode: String?) async throws -> Package? {
        let packages = try await fetchCreditPackages()
        guard !packages.isEmpty else { return nil }
        let code = (currencyCode ?? packages.first?.storeProduct.currencyCode ?? "USD").uppercased()
        let neededUSD = neededUSDCredits(amount: amount, currencyCode: code)

        let covering = packages.filter { package in
            let product = package.storeProduct
            if let productCurrency = product.currencyCode?.uppercased(), productCurrency == code {
                return product.price >= amount
            }
            if let usd = creditUSDByProductID[product.productIdentifier] {
                return usd >= neededUSD
            }
            return false
        }
        return covering.first ?? packages.first
    }

    private static func neededUSDCredits(amount: Decimal, currencyCode: String) -> Decimal {
        switch currencyCode.uppercased() {
        case "USD":
            return amount
        case "RUB":
            return amount / DirectMoney.rublesPerUSD
        default:
            return amount
        }
    }

    public static func purchase(package: Package) async throws -> (CustomerInfo, String?) {
        configureIfNeeded()
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            throw DirectRevenueCatError.cancelled
        }
        return (result.customerInfo, result.transaction?.transactionIdentifier)
    }

    public static func purchase(product: StoreProduct) async throws -> (CustomerInfo, String?) {
        configureIfNeeded()
        let result = try await Purchases.shared.purchase(product: product)
        if result.userCancelled {
            throw DirectRevenueCatError.cancelled
        }
        return (result.customerInfo, result.transaction?.transactionIdentifier)
    }

    /// Buys the cheapest credit pack that covers `amount`, then returns product id + customer info.
    @discardableResult
    public static func purchaseCreditsCovering(amount: Decimal, currencyCode: String?) async throws -> (productID: String, info: CustomerInfo) {
        if let package = try await packageCovering(amount: amount, currencyCode: currencyCode) {
            let (info, _) = try await purchase(package: package)
            return (package.storeProduct.productIdentifier, info)
        }
        let products = try await fetchCreditStoreProducts()
        guard !products.isEmpty else {
            throw DirectRevenueCatError.productsUnavailable
        }
        let code = (currencyCode ?? products.first?.currencyCode ?? "USD").uppercased()
        let neededUSD = neededUSDCredits(amount: amount, currencyCode: code)
        let pick = products.first { product in
            if let productCurrency = product.currencyCode?.uppercased(), productCurrency == code {
                return product.price >= amount
            }
            if let usd = creditUSDByProductID[product.productIdentifier] {
                return usd >= neededUSD
            }
            return false
        } ?? products.first!
        let (info, _) = try await purchase(product: pick)
        return (pick.productIdentifier, info)
    }
}

public enum DirectRevenueCatError: LocalizedError, Equatable {
    case cancelled
    case productsUnavailable
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Покупка отменена"
        case .productsUnavailable:
            return "Пакеты пополнения пока недоступны в App Store. Дождитесь Ready to Submit / Sandbox."
        case .notConfigured:
            return "RevenueCat не настроен"
        }
    }
}

#endif
