import ApplicationLibrary
import FileProvider
import Foundation
import Libbox
import Library
import Network
import UIKit
import UserNotifications

class ApplicationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var profileServer: ProfileServer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NSLog("Here I stand")
        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        var error: NSError?
        LibboxSetup(options, &error)
        LibboxSetLocale(Locale.current.identifier, &error)
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([
            UNNotificationCategory(
                identifier: "OPEN_URL",
                actions: [
                    UNNotificationAction(identifier: "COPY_URL", title: "Copy URL", options: .foreground, icon: UNNotificationActionIcon(systemImageName: "clipboard.fill")),
                    UNNotificationAction(identifier: "OPEN_URL", title: "Open", options: .foreground, icon: UNNotificationActionIcon(systemImageName: "safari.fill")),
                ],
                intentIdentifiers: []
            ),
        ])
        notificationCenter.delegate = self
        requestPushAuthorization(application)
        setup()
        return true
    }

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        UserDefaults.standard.set(token, forKey: "vpndirect.apns.token")
        UserDefaults.standard.set(environment, forKey: "vpndirect.apns.env")
        Task {
            DirectBackendRuntime.warmUp()
            guard let register = DirectBackendRuntime.registerPushToken else { return }
            try? await register(token, environment)
        }
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("APNs registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if Self.isCheckoutPaid(userInfo) {
            NotificationCenter.default.post(name: .vpnDirectCheckoutPaid, object: nil)
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if Self.isCheckoutPaid(userInfo) {
            VPNDirectDeepLink.markPendingPaySuccess()
            await MainActor.run {
                NotificationCenter.default.post(name: .vpnDirectCheckoutPaid, object: nil)
                NotificationCenter.default.post(name: .vpnDirectPaySuccess, object: nil)
            }
            return
        }
        VPNDirectDeepLink.applyPushUserInfo(userInfo)
        if VPNDirectDeepLink.consumePendingPlans() {
            VPNDirectDeepLink.markPendingPlans()
            await MainActor.run {
                NotificationCenter.default.post(name: .vpnDirectOpenPlans, object: nil)
            }
            return
        }
        if VPNDirectDeepLink.consumePendingAccount() {
            VPNDirectDeepLink.markPendingAccount()
            await MainActor.run {
                NotificationCenter.default.post(name: .vpnDirectOpenAccount, object: nil)
            }
            return
        }
        if let deeplink = userInfo["deeplink"] as? String,
           let url = URL(string: deeplink),
           url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
        {
            await UIApplication.shared.open(url)
            return
        }
        if let url = userInfo["OPEN_URL"] as? String {
            switch response.actionIdentifier {
            case "COPY_URL":
                UIPasteboard.general.string = url
            default:
                await UIApplication.shared.open(URL(string: url)!)
            }
        }
    }

    private func requestPushAuthorization(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    private static func isCheckoutPaid(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let type = userInfo["type"] as? String, type == "checkout_paid" {
            return true
        }
        return false
    }

    private func setup() {
        do {
            try UIProfileUpdateTask.configure()
            NSLog("setup background task success")
        } catch {
            NSLog("setup background task error: \(error.localizedDescription)")
        }
        Task {
            if UIDevice.current.userInterfaceIdiom == .phone {
                await requestNetworkPermission()
            }
            await setupBackground()
        }
    }

    private nonisolated func setupBackground() async {
        if #available(iOS 16.0, *) {
            do {
                let profileServer = try ProfileServer()
                profileServer.start()
                await MainActor.run {
                    self.profileServer = profileServer
                }
                NSLog("started profile server")
            } catch {
                NSLog("setup profile server error: \(error.localizedDescription)")
            }
            registerFileProviderDomain()
        }
    }

    @available(iOS 16.0, *)
    private nonisolated func registerFileProviderDomain() {
        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(AppConfiguration.fileProviderDomainID),
            displayName: "VPN Direct"
        )
        NSFileProviderManager.add(domain) { error in
            if let error {
                NSLog("Failed to add file provider domain: \(error)")
            }
        }
    }

    private nonisolated func requestNetworkPermission() async {
        if await SharedPreferences.networkPermissionRequested.get() {
            return
        }
        if !DeviceCensorship.isChinaDevice() {
            await SharedPreferences.networkPermissionRequested.set(true)
            return
        }
        URLSession.shared.dataTask(with: URL(string: "http://captive.apple.com")!) { _, response, _ in
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    Task {
                        await SharedPreferences.networkPermissionRequested.set(true)
                    }
                }
            }
        }.resume()
    }
}
