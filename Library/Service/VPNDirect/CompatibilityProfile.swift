import Foundation

/// Soft panel / client profile inferred from HTTP headers + body shape — never domain alone.
public struct CompatibilityProfile: Equatable, Sendable {
    public var id: String
    public var confidence: Double
    public var signals: [String]

    public static let generic = CompatibilityProfile(id: "generic", confidence: 0, signals: [])

    public static func detect(headers: [String: String], body: String) -> CompatibilityProfile {
        let normalized = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        var scores: [String: (Double, [String])] = [:]

        func bump(_ id: String, _ amount: Double, _ signal: String) {
            var cur = scores[id] ?? (0, [])
            cur.0 += amount
            cur.1.append(signal)
            scores[id] = cur
        }

        if normalized["x-hwid-active"] != nil || normalized["x-hwid-limit"] != nil
            || normalized["x-hwid-max-devices-reached"] != nil || normalized["x-hwid-not-supported"] != nil
        {
            bump("remnawave", 0.45, "hwid-headers")
        }
        if normalized["x-provider-id"] != nil {
            bump("remnawave", 0.2, "x-provider-id")
        }
        if normalized["routing"] != nil || normalized["routing-enable"] != nil {
            bump("3x-ui", 0.25, "happ-routing-headers")
            bump("happ", 0.15, "happ-routing-headers")
        }
        if normalized["announce"] != nil, normalized["profile-title"] != nil {
            bump("3x-ui", 0.2, "announce+title")
        }
        if normalized["profile-update-interval"] != nil, normalized["subscription-userinfo"] != nil {
            bump("3x-ui", 0.15, "userinfo+interval")
            bump("generic", 0.05, "userinfo+interval")
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["), trimmed.contains("\"outbounds\""), trimmed.contains("\"remarks\"") {
            bump("remnawave", 0.35, "xray-json-array-remarks")
        }
        if trimmed.contains("proxies:"), trimmed.contains("proxy-groups:") {
            bump("clash", 0.3, "clash-proxy-groups")
        }
        if trimmed.contains("\"inbounds\""), trimmed.contains("\"outbounds\""), trimmed.contains("\"route\"")
            || trimmed.contains("\"route\":")
        {
            bump("sing-box", 0.25, "sing-box-shape")
        }

        let best = scores.max { $0.value.0 < $1.value.0 }
        guard let best, best.value.0 >= 0.35 else {
            return .generic
        }
        return CompatibilityProfile(id: best.key, confidence: min(1, best.value.0), signals: best.value.1)
    }
}
