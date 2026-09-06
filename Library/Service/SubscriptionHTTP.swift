import Foundation
#if canImport(UIKit)
    import UIKit
#endif

enum SubscriptionHTTP {
    struct Response {
        let body: String
        let headers: [String: String]
    }

    /// Remnawave / Happ-compatible clients require X-HWID. Without it this panel
    /// returns a stub: vless://…@127.0.0.1:1#Приложение не поддерживается
    /// Prefer Happ UA so Remnawave returns native XRAY_JSON (same as Direct / Happ clients).
    /// Fallback UAs may return base64 share-link lists instead.
    static let userAgents: [String] = [
        "Happ/3.13.0",
        "vpndirect",
        "VPN Direct/1.0.0",
        "sfi/1.0.0 vpndirect",
    ]

    static func fetch(url: String, userAgent: String) async throws -> Response {
        guard let requestURL = URL(string: url) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/plain, application/json, */*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

        // Same device headers Happ sends (Remnawave HWID Device Limit / panel filters).
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

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw NSError(
                domain: "SubscriptionHTTP",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
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
        return Response(body: text, headers: headers)
    }

    static func getString(url: String, userAgent: String) async throws -> String {
        try await fetch(url: url, userAgent: userAgent).body
    }
}

enum DeviceIdentity {
    struct Info {
        let hwid: String
        let osName: String
        let osVersion: String
        let model: String
        let locale: String
    }

    private static let hwidKey = "vpndirect.subscription.hwid.v2"

    static var current: Info {
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

    /// Real per-install device id, same style as Happ: vendor UUID without dashes.
    /// Remnawave accepts `/^[a-zA-Z0-9=-]{10,64}$/`.
    private static func stableHWID() -> String {
        if let existing = UserDefaults.standard.string(forKey: hwidKey),
           existing.range(of: #"^[a-zA-Z0-9=-]{10,64}$"#, options: .regularExpression) != nil
        {
            return existing
        }

        #if os(iOS) || os(tvOS)
            let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
            let seed = UUID().uuidString
        #endif

        // 32 hex chars from identifierForVendor — stable for this app on this device.
        let hwid = String(seed.replacingOccurrences(of: "-", with: "").prefix(32))
        UserDefaults.standard.set(hwid, forKey: hwidKey)
        // Drop legacy synthetic ids from earlier builds.
        UserDefaults.standard.removeObject(forKey: "vpndirect.subscription.hwid")
        return hwid
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
