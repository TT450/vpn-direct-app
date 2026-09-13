import Foundation

#if os(iOS)

/// Shared RUB ↔ USD money helper for balance charge / display.
///
/// Charge formula (spend from balance):
/// 1. Rapira USDT/RUB **ask** (buy USDT with rubles) — https://rapira.net/ru/
/// 2. `usd = rubles / ask`
/// 3. `usd *= 1.40` (+40%)
/// 4. Round to **1 decimal** dollar (e.g. 4.76 → 4.8)
/// 5. Store / compare as USD cents (4.8$ → 480)
public enum DirectMoney {
    public static let markupMultiplier: Decimal = Decimal(string: "1.40")!
    /// Public Rapira market rates (no auth).
    public static let rapiraRatesURL = URL(string: "https://api.rapira.net/open/market/rates")!

    /// Last known Rapira ask (RUB per 1 USDT). Fallback until the first refresh.
    public static var usdtRubAsk: Decimal = Decimal(string: "87.77")!
    public static var rateUpdatedAt: Date?

    /// Legacy alias used by a few call sites that need “RUB per 1 USD” mid estimate.
    public static var rublesPerUSD: Decimal { usdtRubAsk }
    public static var usdPerRub: Decimal { Decimal(1) / max(usdtRubAsk, Decimal(string: "0.0001")!) }

    // MARK: - Charge (tariff RUB → balance USD cents)

    /// USD cents to charge for a RUB tariff/quote (Rapira ask + 40%, round to 0.1$).
    public static func usdCents(fromRubles rubles: Int) -> Int {
        chargeUSD(fromRubles: rubles).cents
    }

    public static func chargeUSD(fromRubles rubles: Int) -> (dollars: Decimal, cents: Int) {
        let ask = max(usdtRubAsk, Decimal(string: "0.0001")!)
        let base = Decimal(max(0, rubles)) / ask
        let marked = base * markupMultiplier
        let tenths = (marked * Decimal(10)).rounded(scale: 0, mode: .plain)
        let dollars = tenths / Decimal(10)
        let cents = NSDecimalNumber(decimal: dollars * Decimal(100)).intValue
        return (dollars, max(0, cents))
    }

    /// Market RUB estimate from USD cents (no +40% markup) — for balance ↔ RUB display.
    public static func rubles(fromUSDCents cents: Int) -> Int {
        let usd = Decimal(max(0, cents)) / Decimal(100)
        let rub = usd * usdtRubAsk
        return max(0, NSDecimalNumber(decimal: rub.rounded(scale: 0, mode: .plain)).intValue)
    }

    public static func formatUSD(cents: Int) -> String {
        let value = NSDecimalNumber(decimal: Decimal(max(0, cents)) / Decimal(100)).doubleValue
        // Charge amounts are tenths of a dollar; IAP packs keep two decimals when needed.
        if max(0, cents) % 10 == 0 {
            return String(format: "%.1f$", value)
        }
        return String(format: "%.2f$", value)
    }

    /// Tariff / checkout amounts quoted in RUB → show charge USD.
    public static func display(rubles: Int) -> String {
        let charge = chargeUSD(fromRubles: rubles)
        return "\(max(0, rubles)) ₽ / \(formatUSD(cents: charge.cents))"
    }

    /// Balance ledger amounts stored as USD cents.
    public static func display(usdCents cents: Int) -> String {
        let rub = rubles(fromUSDCents: cents)
        return "\(rub) ₽ / \(formatUSD(cents: cents))"
    }

    public static func displaySigned(usdCents cents: Int) -> String {
        let sign = cents >= 0 ? "+" : "−"
        return "\(sign)\(display(usdCents: abs(cents)))"
    }

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

    // MARK: - Rapira rate

    @discardableResult
    public static func refreshRapiraAskRate() async -> Decimal? {
        var request = URLRequest(url: rapiraRatesURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let ask = parseUSDTRubAsk(from: data) else { return nil }
            usdtRubAsk = ask
            rateUpdatedAt = Date()
            return ask
        } catch {
            return nil
        }
    }

    public static func parseUSDTRubAsk(from data: Data) -> Decimal? {
        struct Envelope: Decodable {
            let data: [Row]?
        }
        struct Row: Decodable {
            let symbol: String?
            let askPrice: Double?
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        guard let row = envelope.data?.first(where: { ($0.symbol ?? "").uppercased() == "USDT/RUB" }),
              let ask = row.askPrice, ask > 0 else {
            return nil
        }
        return Decimal(ask)
    }
}

private extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}

#endif
