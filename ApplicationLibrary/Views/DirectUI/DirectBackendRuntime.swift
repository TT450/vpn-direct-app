import Foundation

#if os(iOS)

@_silgen_name("direct_backend_hooks_install")
func _direct_backend_hooks_install()

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
    public static var signInWithApple: ((VPNConnectionModel) async -> Void)?

    /// Installs local-only hooks when present; weak no-op stub otherwise.
    public static func warmUp() {
        _direct_backend_hooks_install()
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
