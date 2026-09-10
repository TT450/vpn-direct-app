import Foundation
#if canImport(WidgetKit)
    import WidgetKit
#endif

/// Shared App Group status for home-screen widgets and Control Center.
///
/// Do **not** call `ControlCenter.reloadControls` from the packet tunnel —
/// that historically re-fired `SetValueIntent(false)` and killed a healthy
/// tunnel ~2s after dial. Reloading controls from the app process is OK.
public enum DirectWidgetStatusBridge {
    public static let connectedKey = "widget.vpn.connected"
    public static let serverKey = "widget.vpn.server"
    public static let countryKey = "widget.vpn.country"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConfiguration.appGroupID)
    }

    public static func publish(connected: Bool, serverName: String, countryCode: String) {
        guard let defaults else { return }
        let previous = defaults.object(forKey: connectedKey) as? Bool
        defaults.set(connected, forKey: connectedKey)
        defaults.set(serverName, forKey: serverKey)
        defaults.set(countryCode.uppercased(), forKey: countryKey)
        defaults.synchronize()

        guard previous != connected else { return }
        reloadHomeWidget()
        reloadControlCenter()
    }

    public static func readConnected() -> Bool? {
        guard let defaults, defaults.object(forKey: connectedKey) != nil else { return nil }
        return defaults.bool(forKey: connectedKey)
    }

    public static func readSnapshot() -> (connected: Bool, serverName: String, countryCode: String)? {
        guard let defaults, defaults.object(forKey: connectedKey) != nil else { return nil }
        return (
            defaults.bool(forKey: connectedKey),
            defaults.string(forKey: serverKey) ?? "VPN Direct",
            defaults.string(forKey: countryKey) ?? ""
        )
    }

    private static func reloadHomeWidget() {
        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "\(AppConfiguration.packageName).widget.Status")
        #endif
    }

    private static func reloadControlCenter() {
        #if canImport(WidgetKit)
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadControls(ofKind: AppConfiguration.widgetControlKind)
            }
        #endif
    }
}
