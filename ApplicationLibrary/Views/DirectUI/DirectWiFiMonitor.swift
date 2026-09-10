import CoreLocation
import NetworkExtension
import UIKit

#if os(iOS)

public enum DirectWiFiAccess: Equatable {
    case ready
    case needsPermission
    case denied
    case unavailable
}

@MainActor
enum DirectWiFiMonitor {
    private static let auth = LocationAuthBroker()

    static func currentSSID() async -> String? {
        let access = await accessStatus()
        guard access == .ready else { return nil }
        return await NEHotspotNetwork.fetchCurrent()?.ssid
    }

    static func accessStatus() async -> DirectWiFiAccess {
        let resolved = await auth.ensureAuthorized()
        switch resolved {
        case .authorizedWhenInUse, .authorizedAlways:
            return .ready
        case .notDetermined:
            return .needsPermission
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .unavailable
        }
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

@MainActor
private final class LocationAuthBroker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func ensureAuthorized() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        switch current {
        case .authorizedAlways, .authorizedWhenInUse, .denied, .restricted:
            return current
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return current
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let continuation else { return }
            let status = manager.authorizationStatus
            guard status != .notDetermined else { return }
            self.continuation = nil
            continuation.resume(returning: status)
        }
    }
}

#endif
