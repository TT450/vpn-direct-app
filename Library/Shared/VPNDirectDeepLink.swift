import Foundation

public enum VPNDirectDeepLink {
    public static let toggleHost = "toggle"
    public static let pendingToggleKey = "vpndirect.widget.pendingToggle"

    public static var toggleURL: URL { URL(string: "vpndirect://toggle")! }

    public static func markPendingToggle() {
        UserDefaults.standard.set(true, forKey: pendingToggleKey)
    }

    public static func consumePendingToggle() -> Bool {
        guard UserDefaults.standard.bool(forKey: pendingToggleKey) else { return false }
        UserDefaults.standard.set(false, forKey: pendingToggleKey)
        return true
    }
}

public extension Notification.Name {
    static let vpnDirectWidgetToggle = Notification.Name("vpnDirectWidgetToggle")
}
