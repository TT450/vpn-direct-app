import Foundation

#if os(iOS)

/// Public injectable bindings. Defaults are empty/no-op (safe for GitHub).
/// Local `DirectBackendHooks.swift` fills real hosts and API handlers at launch.
public enum DirectBackendRuntime {
    public static var host: String = ""
    public static var baseURLString: String = ""
    public static var legacyIP: String = ""
    public static var subscriptionHost: String = ""
    public static var subscriptionBaseURLString: String = ""

    public static var ownedHosts: () -> [String] = { [] }
    public static var fetchLocations: () async throws -> [DirectLocationRecord] = { [] }
    public static var isAuthenticated: () -> Bool = {
        UserDefaults.standard.bool(forKey: "vpndirect.authenticated")
    }

    public static var startCheckout: ((VPNConnectionModel) async -> Void)?
    public static var finalizeCheckout: ((VPNConnectionModel, String) async -> Void)?
    public static var logout: ((VPNConnectionModel) async -> Void)?
    public static var refreshAccount: ((VPNConnectionModel) async -> Void)?
    public static var bootstrapSession: ((VPNConnectionModel) async -> Void)?
    public static var sendEmailCode: ((VPNConnectionModel, String) async -> Void)?
    public static var resendEmailCode: ((VPNConnectionModel) async -> Void)?
    public static var verifyEmailCode: ((VPNConnectionModel) async -> Void)?
    public static var linkBotCode: ((VPNConnectionModel) async -> Void)?
    public static var requestBotLoginConfirm: ((VPNConnectionModel, String) async -> Void)?
    public static var signInWithTelegram: ((VPNConnectionModel) async -> Void)?
    public static var sendPhoneCode: ((VPNConnectionModel, String) async -> Void)?
    public static var verifyPhoneCode: ((VPNConnectionModel) async -> Void)?
    public static var signInWithApple: ((VPNConnectionModel) async -> Void)?
    public static var signInWithGoogle: ((VPNConnectionModel) async -> Void)?
    public static var loginWithPassword: ((VPNConnectionModel, String, String) async -> Void)?
    public static var registerWithPassword: ((VPNConnectionModel, String, String, String, String) async -> Void)?
    public static var requestPasswordReset: ((VPNConnectionModel, String) async -> Bool)?

    /// Optional Google OAuth client id (filled by local hooks). Empty = Google button shows setup error.
    public static var googleClientID: String = ""
    public static var googleRedirectURI: String = "vpndirect:/oauth2redirect/google"
    /// Hosted Telegram Login Widget page (local hooks may override).
    public static var telegramLoginURLString: String = ""
    /// Hosts/suffixes where external checkout WebView `/success` counts as paid (local hooks).
    public static var checkoutSuccessHostSuffixes: [String] = []

    /// Installs local-only hooks when present; no-op on public clones.
    ///
    /// Uses ObjC class lookup only — do **not** use `@_silgen_name` + `@_cdecl`
    /// with the same symbol name in this module: Release specialization turned
    /// `warmUp()` into a bare `brk #1` and crashed on every launch.
    /// SFI still links ApplicationLibrary with `-force_load` so the local
    /// `DirectBackendHooksEntry` object file is not dropped.
    public static func warmUp() {
        guard signInWithApple == nil else { return }
        guard let cls = NSClassFromString("DirectBackendHooksEntry") as? NSObject.Type else {
            return
        }
        _ = cls.perform(NSSelectorFromString("shared"))
    }
}

/// Facade used by product UI. Values come from `DirectBackendRuntime` (local install).
public enum DirectBackend {
    public static var host: String { DirectBackendRuntime.host }
    public static var baseURLString: String { DirectBackendRuntime.baseURLString }
    public static var legacyIP: String { DirectBackendRuntime.legacyIP }
    public static var subscriptionHost: String { DirectBackendRuntime.subscriptionHost }
    public static var subscriptionBaseURLString: String { DirectBackendRuntime.subscriptionBaseURLString }
    public static var baseURL: URL {
        URL(string: baseURLString) ?? URL(string: "https://invalid.local")!
    }
}

#endif
