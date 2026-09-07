import Foundation
import Security
#if canImport(UIKit)
    import UIKit
#endif

/// Happ / Remnawave subscription identity — separate from app `HTTPClient` UA.
///
/// Rule: remote subscription fetch always starts as Happ. Brand UAs are fallback only
/// when the Happ response cannot be used (rejected stub, empty, unparsable).
public enum SubscriptionClientIdentity {
    /// Primary panel-compatible UA. Must stay first in `userAgents`.
    public static let primaryUserAgent = "Happ/3.13.0"

    /// Ordered agents for subscription fetch only. Index 0 is always Happ.
    public static let userAgents: [String] = [
        primaryUserAgent,
        "vpndirect",
        "VPN Direct/1.0.0",
        "sfi/1.0.0 vpndirect",
    ]

    public static var device: DeviceIdentity.Info { DeviceIdentity.current }

    /// Applies Remnawave / Happ device headers (case variants for panel compatibility).
    public static func applyDeviceHeaders(to request: inout URLRequest) {
        let device = DeviceIdentity.current
        request.setValue(device.hwid, forHTTPHeaderField: "X-HWID")
        request.setValue(device.hwid, forHTTPHeaderField: "x-hwid")
        request.setValue(device.osName, forHTTPHeaderField: "X-Device-OS")
        request.setValue(device.osName, forHTTPHeaderField: "x-device-os")
        request.setValue(device.osVersion, forHTTPHeaderField: "X-Ver-OS")
        request.setValue(device.osVersion, forHTTPHeaderField: "x-ver-os")
        request.setValue(device.model, forHTTPHeaderField: "X-Device-Model")
        request.setValue(device.model, forHTTPHeaderField: "x-device-model")
        request.setValue(device.locale, forHTTPHeaderField: "X-Device-Locale")
    }
}

enum SubscriptionHTTP {
    struct Response {
        let body: String
        let headers: [String: String]
        let userAgent: String
    }

    /// HTTP 304 — body unchanged since cached validators (`If-None-Match` / `If-Modified-Since`).
    struct ConditionalNotModified: Error, Equatable {}

    /// Compatibility alias — always Happ-first via `SubscriptionClientIdentity`.
    static var userAgents: [String] { SubscriptionClientIdentity.userAgents }

    static func fetch(
        url: String,
        userAgent: String,
        cachedETag: String? = nil,
        cachedLastModified: String? = nil
    ) async throws -> Response {
        guard let requestURL = URL(string: url) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/plain, application/json, */*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        if let cachedETag, !cachedETag.isEmpty {
            request.setValue(cachedETag, forHTTPHeaderField: "If-None-Match")
        }
        if let cachedLastModified, !cachedLastModified.isEmpty {
            request.setValue(cachedLastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        SubscriptionClientIdentity.applyDeviceHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 304 {
                throw ConditionalNotModified()
            }
            if !(200 ... 299).contains(http.statusCode) {
                throw NSError(
                    domain: "SubscriptionHTTP",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                )
            }
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw NSError(
                domain: "SubscriptionHTTP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Invalid subscription response encoding")]
            )
        }

        var headers: [String: String] = [:]
        if let http = response as? HTTPURLResponse {
            for (key, value) in http.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    headers[key] = value
                }
            }
        }
        return Response(body: text, headers: headers, userAgent: userAgent)
    }

    static func getString(url: String, userAgent: String) async throws -> String {
        try await fetch(url: url, userAgent: userAgent).body
    }
}

/// Stable Remnawave-compatible HWID (vendor UUID without dashes).
/// Prefer Keychain so reinstall / data reset does not burn a new device slot when possible.
public enum DeviceIdentity {
    public struct Info {
        public let hwid: String
        public let osName: String
        public let osVersion: String
        public let model: String
        public let locale: String
    }

    private static let defaultsKeyV2 = "vpndirect.subscription.hwid.v2"
    private static let defaultsKeyLegacy = "vpndirect.subscription.hwid"
    private static let keychainService = "com.vpndirect.vpndirectapp.subscription"
    private static let keychainAccount = "hwid.v2"

    public static var current: Info {
        #if os(iOS) || os(tvOS)
            let osName = "iOS"
            let osVersion = UIDevice.current.systemVersion
            let model = machineIdentifier()
        #elseif os(macOS)
            let osName = "macOS"
            let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            let model = machineIdentifier()
        #else
            let osName = "unknown"
            let osVersion = "0"
            let model = "device"
        #endif

        return Info(
            hwid: stableHWID(),
            osName: osName,
            osVersion: sanitizeVersion(osVersion),
            model: String(model.prefix(32)),
            locale: Locale.current.identifier
        )
    }

    /// Remnawave accepts `/^[a-zA-Z0-9=-]{10,64}$/`.
    private static func stableHWID() -> String {
        if let keychain = readKeychain(), isValidHWID(keychain) {
            return keychain
        }

        if let existing = UserDefaults.standard.string(forKey: defaultsKeyV2), isValidHWID(existing) {
            writeKeychain(existing)
            return existing
        }

        if let legacy = UserDefaults.standard.string(forKey: defaultsKeyLegacy), isValidHWID(legacy) {
            writeKeychain(legacy)
            UserDefaults.standard.set(legacy, forKey: defaultsKeyV2)
            UserDefaults.standard.removeObject(forKey: defaultsKeyLegacy)
            return legacy
        }

        #if os(iOS) || os(tvOS)
            let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
            let seed = UUID().uuidString
        #endif

        let hwid = String(seed.replacingOccurrences(of: "-", with: "").prefix(32))
        writeKeychain(hwid)
        UserDefaults.standard.set(hwid, forKey: defaultsKeyV2)
        UserDefaults.standard.removeObject(forKey: defaultsKeyLegacy)
        return hwid
    }

    private static func isValidHWID(_ value: String) -> Bool {
        value.range(of: #"^[a-zA-Z0-9=-]{10,64}$"#, options: .regularExpression) != nil
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private static func writeKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func machineIdentifier() -> String {
        #if os(iOS) || os(tvOS) || os(macOS)
            var systemInfo = utsname()
            uname(&systemInfo)
            let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
            }
            if !identifier.isEmpty { return identifier }
        #endif
        #if os(iOS) || os(tvOS)
            return UIDevice.current.model.replacingOccurrences(of: " ", with: "")
        #else
            return "Mac"
        #endif
    }

    private static func sanitizeVersion(_ raw: String) -> String {
        let digits = raw.split(whereSeparator: { !$0.isNumber && $0 != "." }).joined()
        return digits.isEmpty ? "18.0" : String(digits.prefix(16))
    }
}
