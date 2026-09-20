import Foundation
import UIKit
import UserNotifications

#if os(iOS)

/// Centralized APNs permission + device-token registration for VPN Direct.
///
/// The system alert only appears while status is `.notDetermined`, and only if
/// `requestAuthorization` runs on the main thread **after** the first window is up.
/// Calling it from `didFinishLaunching` / overlapping `becomeActive` often eats the dialog.
public enum DirectPushRegistration {
    private static let promptLock = NSLock()
    private static var didRequestPromptThisProcess = false

    /// Register for APNs if already allowed. Does **not** show the permission alert.
    public static func registerIfAuthorized() {
        let application = UIApplication.shared
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            NSLog("APNs status=\(settings.authorizationStatus.rawValue)")
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            default:
                break
            }
        }
    }

    /// Show the system notification permission alert once (if still undetermined).
    /// Call after splash / when the UI is visible.
    public static func requestPermissionIfNeeded() {
        DispatchQueue.main.async {
            promptLock.lock()
            let already = didRequestPromptThisProcess
            if !already { didRequestPromptThisProcess = true }
            promptLock.unlock()
            guard !already else {
                registerIfAuthorized()
                return
            }

            let application = UIApplication.shared
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                NSLog("APNs pre-prompt status=\(settings.authorizationStatus.rawValue)")
                switch settings.authorizationStatus {
                case .notDetermined:
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if let error {
                            NSLog("APNs authorization error: \(error.localizedDescription)")
                        }
                        NSLog("APNs authorization granted=\(granted)")
                        guard granted else { return }
                        DispatchQueue.main.async {
                            application.registerForRemoteNotifications()
                        }
                    }
                case .authorized, .provisional, .ephemeral:
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                case .denied:
                    NSLog("APNs authorization previously denied — enable in Settings → VPN Direct → Notifications")
                @unknown default:
                    break
                }
            }
        }
    }

    /// Back-compat name used from hooks / privacy accept.
    public static func ensureAuthorizedAndRegistered() {
        requestPermissionIfNeeded()
    }

    /// Upload cached device token once a Direct session exists (endpoint is authed).
    public static func uploadCachedTokenIfPossible() async {
        DirectBackendRuntime.warmUp()
        guard let register = DirectBackendRuntime.registerPushToken else { return }
        guard let token = UserDefaults.standard.string(forKey: "vpndirect.apns.token"),
              !token.isEmpty
        else { return }
        let env = UserDefaults.standard.string(forKey: "vpndirect.apns.env") ?? "production"
        try? await register(token, env)
    }
}

#endif
