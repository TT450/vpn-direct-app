import Foundation

#if os(iOS)

/// Shared RUB ↔ USD presentation. Ledger / InAppBalance use USD cents on the backend.
public enum DirectMoney {
    /// Presentation-only bridge until backend quotes both currencies.
    public static let rublesPerUSD: Decimal = Decimal(string: "84.25")!
    public static let usdPerRub: Decimal = Decimal(1) / rublesPerUSD

    public static func usdCents(fromRubles rubles: Int) -> Int {
        let usd = Decimal(max(0, rubles)) * usdPerRub
        let cents = usd * Decimal(100)
        return max(0, NSDecimalNumber(decimal: cents).rounding(accordingToBehavior: halfUp).intValue)
    }

    public static func rubles(fromUSDCents cents: Int) -> Int {
        let usd = Decimal(max(0, cents)) / Decimal(100)
        let rub = usd * rublesPerUSD
        return max(0, NSDecimalNumber(decimal: rub).rounding(accordingToBehavior: halfUp).intValue)
    }

    public static func formatUSD(cents: Int) -> String {
        let value = NSDecimalNumber(decimal: Decimal(max(0, cents)) / Decimal(100)).doubleValue
        return String(format: "%.2f$", value)
    }

    /// Tariff / shortage amounts that are still quoted in RUB.
    public static func display(rubles: Int) -> String {
        "\(max(0, rubles)) ₽ / \(formatUSD(cents: usdCents(fromRubles: rubles)))"
    }

    /// Balance amounts stored as USD cents.
    public static func display(usdCents cents: Int) -> String {
        let rub = rubles(fromUSDCents: cents)
        return "\(rub) ₽ / \(formatUSD(cents: cents))"
    }

    public static func displaySigned(usdCents cents: Int) -> String {
        let sign = cents >= 0 ? "+" : "−"
        return "\(sign)\(display(usdCents: abs(cents)))"
    }

    private static let halfUp: NSDecimalNumberHandler = {
        NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }()

    /// Fixed IAP product → USD cents credit (1:1 with App Store face value).
    public static func creditCents(forProductID productID: String) -> Int? {
        let map: [String: Int] = [
            "direct.credits.4.99": 499,
            "direct.credits.9.99": 999,
            "direct.credits.19.99": 1999,
            "direct.credits.49.99": 4999,
            "direct.credits.99.99": 9999,
            "direct.credits.199.99": 19999,
        ]
        return map[productID]
    }
}

#endif
