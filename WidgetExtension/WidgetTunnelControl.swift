import Foundation
import NetworkExtension
import WidgetKit
import os.log
import AppIntents

private let widgetLog = Logger(subsystem: "com.vpndirect.vpndirectapp.widget", category: "Tunnel")

enum WidgetAppConfiguration {
    static let packageName: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "BasePackageIdentifier") as? String,
           !value.isEmpty, !value.contains("$(")
        {
            return value
        }
        return Bundle.main.bundleIdentifier?
            .replacingOccurrences(of: ".widget", with: "")
            ?? "com.vpndirect.vpndirectapp"
    }()

    static let appGroupID: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           !value.isEmpty, !value.contains("$(")
        {
            return value
        }
        return "group.\(packageName)"
    }()

    static var widgetControlKind: String {
        "\(packageName).widget.ServiceToggle"
    }

    static var statusWidgetKind: String {
        "\(packageName).widget.Status"
    }
}

extension NEVPNStatus {
    var isStarted: Bool {
        switch self {
        case .connecting, .connected, .reasserting:
            return true
        default:
            return false
        }
    }
}

enum WidgetStatusStore {
    /// Keys must match `DirectWidgetStatusBridge` in the app target.
    private static let connectedKey = "widget.vpn.connected"
    private static let serverKey = "widget.vpn.server"
    private static let countryKey = "widget.vpn.country"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetAppConfiguration.appGroupID)
    }

    static func readConnected() -> Bool? {
        guard let defaults, defaults.object(forKey: connectedKey) != nil else { return nil }
        return defaults.bool(forKey: connectedKey)
    }

    static func readSnapshot() -> (connected: Bool, serverName: String, countryCode: String)? {
        guard let defaults, defaults.object(forKey: connectedKey) != nil else { return nil }
        return (
            defaults.bool(forKey: connectedKey),
            defaults.string(forKey: serverKey) ?? "VPN Direct",
            defaults.string(forKey: countryKey) ?? ""
        )
    }

    static func write(connected: Bool, serverName: String = "VPN Direct", countryCode: String = "") {
        guard let defaults else { return }
        defaults.set(connected, forKey: connectedKey)
        defaults.set(serverName, forKey: serverKey)
        defaults.set(countryCode.uppercased(), forKey: countryKey)
        defaults.synchronize()
    }
}

enum WidgetTunnelControl {
    /// Live NE status first (widget is signed with packet-tunnel). App Group is optional fallback.
    static func currentIsStarted() async -> Bool {
        do {
            if let manager = try await loadManager() {
                return manager.connection.status.isStarted
            }
        } catch {
            widgetLog.error("currentIsStarted NE failed: \(error.localizedDescription)")
        }
        return WidgetStatusStore.readConnected() ?? false
    }

    /// - Parameter allowEarlyStop: home-screen button taps pass `true`; Control Center sync passes `false`
    ///   so a stale `false` right after dial does not kill the tunnel.
    static func setStarted(_ started: Bool, allowEarlyStop: Bool = false) async throws {
        guard let manager = try await loadManager() else {
            widgetLog.error("No tunnel configuration — open the app once")
            throw NSError(domain: "WidgetTunnelControl", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Сначала откройте VPN Direct и подключитесь один раз",
            ])
        }

        let currently = manager.connection.status.isStarted
        if started == currently {
            widgetLog.info("noop setStarted(\(started))")
            WidgetStatusStore.write(connected: started)
            reloadWidgets()
            return
        }

        if !started, currently, !allowEarlyStop {
            // connectedDate is often nil in the first second — treat as age 0.
            let age = manager.connection.connectedDate.map { Date().timeIntervalSince($0) } ?? 0
            if age < 12 {
                widgetLog.info("ignore Control Center early/nil-date stop (age=\(age))")
                reloadWidgets()
                return
            }
        }

        if started {
            if manager.isEnabled == false {
                manager.isEnabled = true
            }
            if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol,
               var config = proto.providerConfiguration,
               config["wasOnDemandEnabled"] as? Bool == true
            {
                config.removeValue(forKey: "wasOnDemandEnabled")
                proto.providerConfiguration = config
                manager.isOnDemandEnabled = true
            }
            try await manager.saveToPreferences()
            do {
                try manager.connection.startVPNTunnel()
                widgetLog.info("startVPNTunnel OK")
            } catch {
                widgetLog.error("startVPNTunnel failed: \(error.localizedDescription)")
                throw NSError(domain: "WidgetTunnelControl", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Не удалось включить из виджета. Откройте приложение и подключитесь один раз.",
                ])
            }
        } else {
            if manager.isOnDemandEnabled {
                if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    var config = proto.providerConfiguration ?? [:]
                    config["wasOnDemandEnabled"] = true
                    proto.providerConfiguration = config
                }
                manager.isOnDemandEnabled = false
                try await manager.saveToPreferences()
            }
            widgetLog.info("stopVPNTunnel")
            manager.connection.stopVPNTunnel()
        }
        WidgetStatusStore.write(connected: started)
        reloadWidgets()
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetAppConfiguration.statusWidgetKind)
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: WidgetAppConfiguration.widgetControlKind)
        }
    }

    private static func loadManager() async throws -> NETunnelProviderManager? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let wanted = "\(WidgetAppConfiguration.packageName).SingBoxPacketTunnel"
        if let match = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == wanted
        }) {
            return match
        }
        return managers.first
    }
}

// MARK: - Intents (must live in the widget extension target)

/// Home-screen power button — toggles from LIVE NE status (not stale timeline entry).
struct ToggleVPNWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "VPN Direct"
    static var description = IntentDescription("Включить или выключить VPN Direct")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let currently = await WidgetTunnelControl.currentIsStarted()
        try await WidgetTunnelControl.setStarted(!currently, allowEarlyStop: true)
        return .result()
    }
}

/// Control Center toggle — SetValueIntent required by ControlWidgetToggle.
struct ToggleServiceControlIntent: SetValueIntent {
    static var title: LocalizedStringResource = "VPN Direct"
    static var description = IntentDescription("Включить или выключить VPN Direct")

    @Parameter(title: "Включен")
    var value: Bool

    init() {}

    init(value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        let currently = await WidgetTunnelControl.currentIsStarted()
        guard value != currently else { return .result() }
        try await WidgetTunnelControl.setStarted(value, allowEarlyStop: false)
        return .result()
    }
}
