import Foundation

public enum VPNDirectDeepLink {
    public static let toggleHost = "toggle"
    public static let openHost = "open"
    public static let authHost = "auth"
    public static let botHost = "bot"
    public static let payHost = "pay"
    public static let pendingToggleKey = "vpndirect.widget.pendingToggle"
    public static let pendingBotAuthKey = "vpndirect.deeplink.pendingBotAuth"
    public static let pendingPaySuccessKey = "vpndirect.deeplink.pendingPaySuccess"
    public static let pendingPayFailKey = "vpndirect.deeplink.pendingPayFail"

    public static var toggleURL: URL { URL(string: "vpndirect://toggle")! }
    public static var botAuthURL: URL { URL(string: "vpndirect://auth/bot")! }
    public static var openURL: URL { URL(string: "vpndirect://open")! }
    public static var paySuccessURL: URL { URL(string: "vpndirect://pay/success")! }
    public static var payFailURL: URL { URL(string: "vpndirect://pay/fail")! }

    public static func markPendingToggle() {
        UserDefaults.standard.set(true, forKey: pendingToggleKey)
    }

    public static func consumePendingToggle() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingToggleKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingToggleKey)
        return true
    }

    public static func markPendingBotAuth() {
        UserDefaults.standard.set(true, forKey: pendingBotAuthKey)
    }

    public static func consumePendingBotAuth() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingBotAuthKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingBotAuthKey)
        return true
    }

    public static func markPendingPaySuccess() {
        UserDefaults.standard.set(true, forKey: pendingPaySuccessKey)
        UserDefaults.standard.set(false, forKey: pendingPayFailKey)
    }

    public static func markPendingPayFail() {
        UserDefaults.standard.set(true, forKey: pendingPayFailKey)
        UserDefaults.standard.set(false, forKey: pendingPaySuccessKey)
    }

    public static func consumePendingPaySuccess() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingPaySuccessKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingPaySuccessKey)
        return true
    }

    public static func consumePendingPayFail() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingPayFailKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingPayFailKey)
        return true
    }

    /// `vpndirect://`, `vpndirect://open`, `vpndirect://bot`, `vpndirect://auth/bot`
    public static func isBotAuthURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "vpndirect" else { return false }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if host.isEmpty { return true }
        if host == openHost || host == botHost { return true }
        if host == authHost, path == botHost || path.hasPrefix("bot/") { return true }
        return false
    }

    /// `vpndirect://pay/success` | `vpndirect://pay/fail`
    public static func payResult(from url: URL) -> Bool? {
        guard url.scheme?.lowercased() == "vpndirect" else { return nil }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard host == payHost else { return nil }
        if path == "success" || path.hasPrefix("success/") { return true }
        if path == "fail" || path == "failed" || path.hasPrefix("fail") { return false }
        return nil
    }
}

public extension Notification.Name {
    static let vpnDirectWidgetToggle = Notification.Name("vpnDirectWidgetToggle")
    static let vpnDirectOpenBotAuth = Notification.Name("vpnDirectOpenBotAuth")
    static let vpnDirectPaySuccess = Notification.Name("vpnDirectPaySuccess")
    static let vpnDirectPayFail = Notification.Name("vpnDirectPayFail")
}
