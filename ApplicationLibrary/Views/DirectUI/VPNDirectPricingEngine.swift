import Foundation

#if os(iOS)

/// Demo local pricing — single place to tune coefficients. Formula is not shown in UI.
public enum VPNDirectPricingEngine {
    /// Duration multipliers for multi-month preset periods (vs plain × months).
    public static let durationMultipliers: [Int: Double] = [
        30: 1.00,
        90: 0.88,
        180: 0.78,
        365: 0.65,
    ]

    public static func price(for plan: PlanConfiguration) -> Int {
        let monthly = monthlyBase(devices: plan.devices, trafficGB: plan.trafficGB, whitelistGB: plan.whitelistGB)
        let months = Double(plan.days) / 30.0
        let multiplier = durationMultiplier(forDays: plan.days)
        let raw = monthly * months * multiplier
        return max(49, Int((raw / 10.0).rounded() * 10))
    }

    /// 30-day sticker price for a resource pack (used to derive longer periods).
    public static func monthlyBase(devices: Int, trafficGB: Int?, whitelistGB: Int) -> Double {
        // Tuned so Plus (300 GB · 50 WL · 3 devices · 30 days) ≈ 799 ₽.
        270.0
            * deviceFactor(devices)
            * trafficFactor(trafficGB)
            * whitelistFactor(whitelistGB)
    }

    public static func durationMultiplier(forDays days: Int) -> Double {
        if let exact = durationMultipliers[days] { return exact }
        // Interpolate constructor periods (7/14) toward 30-day baseline.
        if days < 30 {
            return 1.05
        }
        if days < 90 { return 1.00 }
        if days < 180 { return 0.88 }
        if days < 365 { return 0.78 }
        return 0.65
    }

    private static func deviceFactor(_ devices: Int) -> Double {
        switch devices {
        case ...1: return 1.00
        case 2 ... 3: return 1.55
        case 4 ... 5: return 2.10
        case 6 ... 10: return 3.20
        default: return 4.80
        }
    }

    private static func trafficFactor(_ trafficGB: Int?) -> Double {
        guard let trafficGB else { return 4.20 }
        switch trafficGB {
        case ...50: return 0.70
        case 51 ... 100: return 1.00
        case 101 ... 300: return 1.55
        case 301 ... 500: return 2.00
        case 501 ... 1000: return 2.70
        case 1001 ... 2000: return 3.40
        default: return 4.20
        }
    }

    private static func whitelistFactor(_ whitelistGB: Int) -> Double {
        switch whitelistGB {
        case ...0: return 1.00
        case 1 ... 20: return 1.12
        case 21 ... 50: return 1.22
        case 51 ... 100: return 1.35
        case 101 ... 250: return 1.55
        default: return 1.80
        }
    }
}

#endif
