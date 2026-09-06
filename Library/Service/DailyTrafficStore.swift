import Foundation

/// Persists VPN session traffic per calendar day so disconnect does not reset the counter.
public enum DailyTrafficStore {
    private static let bytesKey = "vpndirect.daily.traffic.bytes"
    private static let dayKey = "vpndirect.daily.traffic.day"

    private static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    public static func todayKey() -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    public static func storedBytesForToday() -> Int64 {
        normalizeDayIfNeeded()
        return Int64(UserDefaults.standard.integer(forKey: bytesKey))
    }

    public static func addBytes(_ delta: Int64) {
        guard delta > 0 else { return }
        normalizeDayIfNeeded()
        let current = Int64(UserDefaults.standard.integer(forKey: bytesKey))
        UserDefaults.standard.set(Int(current + delta), forKey: bytesKey)
    }

    private static func normalizeDayIfNeeded() {
        let currentDay = todayKey()
        let savedDay = UserDefaults.standard.string(forKey: dayKey)
        if savedDay != currentDay {
            UserDefaults.standard.set(currentDay, forKey: dayKey)
            UserDefaults.standard.set(0, forKey: bytesKey)
        }
    }
}
