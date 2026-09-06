import Foundation

/// Injects sing-box `rule_set` rules so Russian domains/IPs go `direct` (no VPN).
public enum RussianBypassRouting {
    private static let managedTags = [
        "vpndirect-geosite-category-ru",
        "vpndirect-geoip-ru",
        "vpndirect-geosite-ru-available-only-inside",
    ]

    private static let ruleSets: [[String: Any]] = [
        [
            "tag": "vpndirect-geosite-category-ru",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/sing-box/rule-set-geosite/geosite-category-ru.srs",
            "download_detour": "proxy",
            "update_interval": "24h",
        ],
        [
            "tag": "vpndirect-geoip-ru",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/sing-box/rule-set-geoip/geoip-ru.srs",
            "download_detour": "proxy",
            "update_interval": "24h",
        ],
        [
            "tag": "vpndirect-geosite-ru-available-only-inside",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/sing-box/rule-set-geosite/geosite-ru-available-only-inside.srs",
            "download_detour": "proxy",
            "update_interval": "24h",
        ],
    ]

    /// Applies or removes managed RU→direct rules. Safe to call repeatedly.
    public static func apply(to json: String, enabled: Bool) -> String {
        guard let data = json.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return json
        }

        var route = root["route"] as? [String: Any] ?? [:]
        var sets = route["rule_set"] as? [[String: Any]] ?? []
        var rules = route["rules"] as? [[String: Any]] ?? []

        sets.removeAll { set in
            guard let tag = set["tag"] as? String else { return false }
            return managedTags.contains(tag)
        }
        rules.removeAll { rule in
            if let tag = rule["rule_set"] as? String {
                return managedTags.contains(tag)
            }
            if let tags = rule["rule_set"] as? [String] {
                return tags.contains(where: { managedTags.contains($0) })
            }
            return false
        }

        if enabled {
            sets.append(contentsOf: ruleSets)
            let insertIndex = rules.firstIndex { rule in
                (rule["ip_is_private"] as? Bool) == true
            }.map { $0 + 1 } ?? rules.count
            let bypassRule: [String: Any] = [
                "rule_set": managedTags,
                "outbound": "direct",
            ]
            rules.insert(bypassRule, at: min(insertIndex, rules.count))
        }

        route["rule_set"] = sets
        route["rules"] = rules
        root["route"] = route

        var experimental = root["experimental"] as? [String: Any] ?? [:]
        var cacheFile = experimental["cache_file"] as? [String: Any] ?? [:]
        cacheFile["enabled"] = true
        experimental["cache_file"] = cacheFile
        root["experimental"] = experimental

        guard let out = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: out, encoding: .utf8)
        else {
            return json
        }
        return text
    }
}
