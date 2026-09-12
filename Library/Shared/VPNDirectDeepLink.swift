import Foundation

public enum VPNDirectDeepLink {
    public static let toggleHost = "toggle"
    public static let openHost = "open"
    public static let authHost = "auth"
    public static let botHost = "bot"
    public static let payHost = "pay"
    public static let plansHost = "plans"
    public static let accountHost = "account"
    public static let managementHost = "management"
    public static let pendingToggleKey = "vpndirect.widget.pendingToggle"
    public static let pendingBotAuthKey = "vpndirect.deeplink.pendingBotAuth"
    public static let pendingPaySuccessKey = "vpndirect.deeplink.pendingPaySuccess"
    public static let pendingPayFailKey = "vpndirect.deeplink.pendingPayFail"
    public static let pendingPlansKey = "vpndirect.deeplink.pendingPlans"
    public static let pendingAccountKey = "vpndirect.deeplink.pendingAccount"

    public static var toggleURL: URL { URL(string: "vpndirect://toggle")! }
    public static var botAuthURL: URL { URL(string: "vpndirect://auth/bot")! }
    public static var openURL: URL { URL(string: "vpndirect://open")! }
    public static var paySuccessURL: URL { URL(string: "vpndirect://pay/success")! }
    public static var payFailURL: URL { URL(string: "vpndirect://pay/fail")! }
    public static var plansURL: URL { URL(string: "vpndirect://plans")! }
    public static var accountURL: URL { URL(string: "vpndirect://account")! }

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

    public static func markPendingPlans() {
        UserDefaults.standard.set(true, forKey: pendingPlansKey)
    }

    public static func consumePendingPlans() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingPlansKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingPlansKey)
        return true
    }

    public static func markPendingAccount() {
        UserDefaults.standard.set(true, forKey: pendingAccountKey)
    }

    public static func consumePendingAccount() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingAccountKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingAccountKey)
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

    /// `vpndirect://plans` | `vpndirect://tariffs`
    public static func isPlansURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "vpndirect" else { return false }
        let host = (url.host ?? "").lowercased()
        return host == plansHost || host == "tariffs" || host == "pricing"
    }

    /// `vpndirect://account` | `vpndirect://profile`
    public static func isAccountURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "vpndirect" else { return false }
        let host = (url.host ?? "").lowercased()
        return host == accountHost || host == "profile"
    }

    /// Route a push `type` / `deeplink` into pending deep-link flags.
    public static func applyPushUserInfo(_ userInfo: [AnyHashable: Any]) {
        if let deeplink = userInfo["deeplink"] as? String,
           let url = URL(string: deeplink)
        {
            if isPlansURL(url) {
                markPendingPlans()
                return
            }
            if isAccountURL(url) {
                markPendingAccount()
                return
            }
            if let paid = payResult(from: url) {
                if paid { markPendingPaySuccess() } else { markPendingPayFail() }
                return
            }
            if isBotAuthURL(url) {
                markPendingBotAuth()
                return
            }
        }
        let type = ((userInfo["type"] as? String) ?? "").lowercased()
        switch type {
        case "checkout_paid", "pay_success":
            markPendingPaySuccess()
        case "open_plans", "plans", "tariffs":
            markPendingPlans()
        case "open_account", "account", "profile":
            markPendingAccount()
        default:
            break
        }
    }
}

public extension Notification.Name {
    static let vpnDirectWidgetToggle = Notification.Name("vpnDirectWidgetToggle")
    static let vpnDirectOpenBotAuth = Notification.Name("vpnDirectOpenBotAuth")
    static let vpnDirectPaySuccess = Notification.Name("vpnDirectPaySuccess")
    static let vpnDirectPayFail = Notification.Name("vpnDirectPayFail")
    static let vpnDirectCheckoutPaid = Notification.Name("vpnDirectCheckoutPaid")
    static let vpnDirectOpenPlans = Notification.Name("vpnDirectOpenPlans")
    static let vpnDirectOpenAccount = Notification.Name("vpnDirectOpenAccount")
}
