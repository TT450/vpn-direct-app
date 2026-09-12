import ApplicationLibrary
import Libbox
import Library
import NetworkExtension
import SwiftUI

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environments: ExtensionEnvironments

    @State private var selection = NavigationPage.dashboard
    @State private var importProfile: LibboxProfileContent?
    @State private var importRemoteProfile: LibboxImportRemoteProfile?
    @State private var alert: AlertState?
    /// Duration of the branded splash after the system Launch Screen.
    private let splashDurationMilliseconds: UInt64 = 1900
    @State private var isShowingSplash = true

    private let profileEditor: (Binding<String>, Bool) -> AnyView = { text, isEditable in
        AnyView(ProfileEditorWrapperView(text: text, isEditable: isEditable))
    }

    var body: some View {
        ZStack {
            mainBody
                .preferredColorScheme(.light)

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            HapticManager.shared.prepare()
            try? await Task.sleep(nanoseconds: splashDurationMilliseconds * 1_000_000)
            withAnimation(.easeInOut(duration: 0.42)) {
                isShowingSplash = false
            }
            HapticManager.shared.play(.navigation)
        }
    }

    private var mainBody: some View {
        VPNHomeView()
            .environmentObject(environments)
            .onAppear {
                environments.postReload()
            }
            .alert($alert)
            .globalChecks()
            .onChangeCompat(of: scenePhase) { newValue in
                if newValue == .active {
                    environments.postReload()
                }
            }
            .environment(\.selection, $selection)
            .environment(\.importProfile, $importProfile)
            .environment(\.importRemoteProfile, $importRemoteProfile)
            .environment(\.profileEditor, profileEditor)
            .handlesExternalEvents(preferring: [], allowing: ["*"])
            .onOpenURL(perform: openURL)
    }

    private func openURL(url: URL) {
        // Home-screen widget tap — always works (opens app + toggles VPN).
        if url.scheme?.lowercased() == "vpndirect", url.host?.lowercased() == VPNDirectDeepLink.toggleHost {
            VPNDirectDeepLink.markPendingToggle()
            NotificationCenter.default.post(name: .vpnDirectWidgetToggle, object: nil)
            return
        }
        // Bot «Open app» / sync flow → screen to enter 6-digit code.
        if VPNDirectDeepLink.isBotAuthURL(url) {
            VPNDirectDeepLink.markPendingBotAuth()
            NotificationCenter.default.post(name: .vpnDirectOpenBotAuth, object: nil)
            return
        }
        // Merchant return → payment success / fail screens.
        if let paid = VPNDirectDeepLink.payResult(from: url) {
            if paid {
                VPNDirectDeepLink.markPendingPaySuccess()
                NotificationCenter.default.post(name: .vpnDirectPaySuccess, object: nil)
            } else {
                VPNDirectDeepLink.markPendingPayFail()
                NotificationCenter.default.post(name: .vpnDirectPayFail, object: nil)
            }
            return
        }
        // Plans / account deep links (push + marketing).
        if VPNDirectDeepLink.isPlansURL(url) {
            VPNDirectDeepLink.markPendingPlans()
            NotificationCenter.default.post(name: .vpnDirectOpenPlans, object: nil)
            return
        }
        if VPNDirectDeepLink.isAccountURL(url) {
            VPNDirectDeepLink.markPendingAccount()
            NotificationCenter.default.post(name: .vpnDirectOpenAccount, object: nil)
            return
        }
        let absolute = AutoSubscriptionImporter.normalizeImportURL(url.absoluteString)
        if VLESSConfigBuilder.isVLESSLink(absolute) || SubscriptionConfigBuilder.isHTTPURL(absolute) {
            Task {
                do {
                    if let profile = try await AutoSubscriptionImporter.importIfNeeded(url: absolute, environments: environments) {
                        environments.profileUpdate.send()
                        _ = profile
                    }
                } catch {
                    await MainActor.run {
                        alert = AlertState(action: "import subscription", error: error)
                    }
                }
            }
            selection = .dashboard
            return
        }
        if url.scheme?.lowercased() == "vpndirect", url.host?.lowercased() == "add" {
            selection = .dashboard
            alert = AlertState(errorMessage: String(localized: "Paste a full vless:// or https:// subscription link."))
            return
        }
        if url.host == "import-remote-profile" {
            var error: NSError?
            importRemoteProfile = LibboxParseRemoteProfileImportLink(url.absoluteString, &error)
            if let error {
                alert = AlertState(action: "parse remote profile import link", error: error)
            }
        } else if url.pathExtension == "bpf" {
            do {
                importProfile = try url.withSecurityScopedAccess {
                    try .from(Data(contentsOf: url))
                }
            } catch {
                alert = AlertState(action: "import profile from URL", error: error)
            }
        } else if url.scheme?.lowercased() == "vpndirect" {
            // Unknown vpndirect:// path — open app quietly (no error alert).
            return
        } else {
            alert = AlertState(errorMessage: String(localized: "Handled unknown URL \(url.absoluteString)"))
        }
    }
}
