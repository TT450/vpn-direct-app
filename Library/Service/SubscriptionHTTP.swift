import Foundation
import Security
#if canImport(UIKit)
    import UIKit
#endif

/// Subscription fetch identity modes. Generic-first for arbitrary hosts; Happ only when negotiated.
public enum SubscriptionFetchMode: String, Sendable {
    /// Minimal UA, no HWID / device headers.
    case generic
    /// Happ / Remnawave compatibility (sends HWID).
    case happ
}

/// Happ / Remnawave subscription identity — separate from app `HTTPClient` UA.
public enum SubscriptionClientIdentity {
    public static let primaryUserAgent = "Happ/3.13.0"
    public static let genericUserAgent = "vpndirect"

    /// Ordered agents: generic first (no HWID), then brand, then Happ (HWID).
    public static let userAgents: [String] = [
        genericUserAgent,
        "VPN Direct/1.0.0",
        "sfi/1.0.0 vpndirect",
        primaryUserAgent,
    ]

    public static var device: DeviceIdentity.Info { DeviceIdentity.current }

    public static func fetchMode(forUserAgent userAgent: String) -> SubscriptionFetchMode {
        userAgent.hasPrefix("Happ/") ? .happ : .generic
    }

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

    /// Headers that must never cross origins or HTTPS→HTTP downgrades.
    public static let sensitiveHeaderNames: Set<String> = [
        "x-hwid",
        "x-device-os",
        "x-ver-os",
        "x-device-model",
        "x-device-locale",
        "authorization",
        "proxy-authorization",
        "cookie",
        "set-cookie",
        "x-api-key",
        "x-auth-token",
    ]

    public static func stripSensitiveHeaders(from request: inout URLRequest) {
        guard let fields = request.allHTTPHeaderFields else { return }
        for key in fields.keys {
            if sensitiveHeaderNames.contains(key.lowercased()) {
                request.setValue(nil, forHTTPHeaderField: key)
            }
        }
    }

    public static func normalizedOrigin(of url: URL?) -> String? {
        guard let url, let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
            return nil
        }
        let port: Int
        if let explicit = url.port {
            port = explicit
        } else if scheme == "https" {
            port = 443
        } else if scheme == "http" {
            port = 80
        } else {
            return nil
        }
        return "\(scheme)://\(host):\(port)"
    }
}

/// Redirect policy: compare full origin; strip identity/auth on cross-origin; reject HTTPS→HTTP.
final class SubscriptionSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let originalURL = task.originalRequest?.url
        let nextURL = request.url
        let originalOrigin = SubscriptionClientIdentity.normalizedOrigin(of: originalURL)
        let nextOrigin = SubscriptionClientIdentity.normalizedOrigin(of: nextURL)

        // Reject cleartext downgrade.
        if let originalURL, let nextURL,
           originalURL.scheme?.lowercased() == "https",
           nextURL.scheme?.lowercased() == "http"
        {
            completionHandler(nil)
            return
        }

        guard let originalOrigin, let nextOrigin else {
            completionHandler(request)
            return
        }
        if originalOrigin == nextOrigin {
            completionHandler(request)
            return
        }
        var stripped = request
        SubscriptionClientIdentity.stripSensitiveHeaders(from: &stripped)
        completionHandler(stripped)
    }
}

enum SubscriptionHTTP {
    struct Response {
        let body: String
        let headers: [String: String]
        let userAgent: String
        let statusCode: Int
        let finalURL: URL?
    }

    /// HTTP non-success with bounded body/headers for panel classification.
    struct HTTPResponseError: Error {
        let statusCode: Int
        let headers: [String: String]
        let body: String
        let finalURL: URL?
        let userAgent: String
    }

    /// HTTP 304 — body unchanged since cached validators (`If-None-Match` / `If-Modified-Since`).
    struct ConditionalNotModified: Error, Equatable {}

    private static let maxBodyBytes = 32 * 1024 * 1024
    private static let maxErrorBodyBytes = 64 * 1024
    private static let sessionDelegate = SubscriptionSessionDelegate()
    private static let session = URLSession(
        configuration: .ephemeral,
        delegate: sessionDelegate,
        delegateQueue: nil
    )

    /// Compatibility alias — generic-first via `SubscriptionClientIdentity`.
    static var userAgents: [String] { SubscriptionClientIdentity.userAgents }

    static func fetch(
        url: String,
        userAgent: String,
        cachedETag: String? = nil,
        cachedLastModified: String? = nil
    ) async throws -> Response {
        guard let requestURL = URL(string: url),
              let scheme = requestURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
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
        // HWID only for Happ mode — never on generic first request to arbitrary hosts.
        if SubscriptionClientIdentity.fetchMode(forUserAgent: userAgent) == .happ {
            SubscriptionClientIdentity.applyDeviceHeaders(to: &request)
        }

        let (bytes, urlResponse) = try await session.bytes(for: request)
        if let http = urlResponse as? HTTPURLResponse {
            if let contentLength = http.value(forHTTPHeaderField: "Content-Length"),
               let length = Int(contentLength),
               length > maxBodyBytes
            {
                throw NSError(
                    domain: "SubscriptionHTTP",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Subscription body exceeds size limit"]
                )
            }
            if http.statusCode == 304 {
                throw ConditionalNotModified()
            }
        }

        var data = Data()
        data.reserveCapacity(min(64 * 1024, maxBodyBytes))
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxBodyBytes {
                throw NSError(
                    domain: "SubscriptionHTTP",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Subscription body exceeds size limit"]
                )
            }
        }

        let headers = headerMap(from: urlResponse)
        let status = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        let finalURL = urlResponse.url

        if !(200 ... 299).contains(status) {
            let bodyPreview = String(data: data.prefix(maxErrorBodyBytes), encoding: .utf8)
                ?? String(data: data.prefix(maxErrorBodyBytes), encoding: .isoLatin1)
                ?? ""
            throw HTTPResponseError(
                statusCode: status,
                headers: headers,
                body: bodyPreview,
                finalURL: finalURL,
                userAgent: userAgent
            )
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw NSError(
                domain: "SubscriptionHTTP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Invalid subscription response encoding")]
            )
        }
        return Response(body: text, headers: headers, userAgent: userAgent, statusCode: status, finalURL: finalURL)
    }

    static func getString(url: String, userAgent: String) async throws -> String {
        try await fetch(url: url, userAgent: userAgent).body
    }

    private static func headerMap(from response: URLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        guard let http = response as? HTTPURLResponse else { return headers }
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return headers
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

    public enum PersistenceStatus: Equatable {
        case keychain
        case defaultsFallback
        case ephemeralUnpersisted
    }

    private static let defaultsKeyV2 = "vpndirect.subscription.hwid.v2"
    private static let defaultsKeyLegacy = "vpndirect.subscription.hwid"
    private static let keychainService = "com.vpndirect.vpndirectapp.subscription"
    private static let keychainAccount = "hwid.v2"

    /// Last persistence outcome (for diagnostics — never log the HWID itself).
    public private(set) static var lastPersistenceStatus: PersistenceStatus = .ephemeralUnpersisted

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
            lastPersistenceStatus = .keychain
            return keychain
        }

        if let existing = UserDefaults.standard.string(forKey: defaultsKeyV2), isValidHWID(existing) {
            if persistKeychain(existing) {
                lastPersistenceStatus = .keychain
            } else {
                lastPersistenceStatus = .defaultsFallback
            }
            return existing
        }

        if let legacy = UserDefaults.standard.string(forKey: defaultsKeyLegacy), isValidHWID(legacy) {
            UserDefaults.standard.set(legacy, forKey: defaultsKeyV2)
            UserDefaults.standard.removeObject(forKey: defaultsKeyLegacy)
            if persistKeychain(legacy) {
                lastPersistenceStatus = .keychain
            } else {
                lastPersistenceStatus = .defaultsFallback
            }
            return legacy
        }

        #if os(iOS) || os(tvOS)
            let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
            let seed = UUID().uuidString
        #endif

        let hwid = String(seed.replacingOccurrences(of: "-", with: "").prefix(32))
        // Do not claim durable Keychain persistence unless write succeeded.
        if persistKeychain(hwid) {
            UserDefaults.standard.set(hwid, forKey: defaultsKeyV2)
            UserDefaults.standard.removeObject(forKey: defaultsKeyLegacy)
            lastPersistenceStatus = .keychain
        } else {
            // Keep defaults so next launch does not rotate while Keychain is unavailable.
            UserDefaults.standard.set(hwid, forKey: defaultsKeyV2)
            lastPersistenceStatus = .defaultsFallback
            NSLog("%@", VPNDirectRedactor.redact("DeviceIdentity keychain unavailable; using defaults fallback"))
        }
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

    /// Update-first; never delete a valid item before a successful replacement.
    @discardableResult
    private static func persistKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return true
            }
            NSLog("%@", VPNDirectRedactor.redact("DeviceIdentity keychain add failed status=\(addStatus)"))
            VPNDirectLog.subscription.error("\(VPNDirectRedactor.redact("hwid_keychain_add_failed status=\(addStatus)"))")
            return false
        }
        NSLog("%@", VPNDirectRedactor.redact("DeviceIdentity keychain update failed status=\(updateStatus)"))
        VPNDirectLog.subscription.error("\(VPNDirectRedactor.redact("hwid_keychain_update_failed status=\(updateStatus)"))")
        return false
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
