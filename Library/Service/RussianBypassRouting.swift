import Foundation

/// Injects sing-box `rule_set` rules so Russian domains/IPs go `direct` (no VPN).
public enum RussianBypassRouting {
    private static let managedTags = [
        "vpndirect-geosite-category-ru",
        "vpndirect-geoip-ru",
        "vpndirect-geosite-ru-available-only-inside",
    ]

    /// Shared HTTP client tag for remote rule-set downloads (sing-box 1.14+; replaces `download_detour`).
    private static let httpClientTag = "vpndirect-ruleset-http"

    private static let ruleSets: [[String: Any]] = [
        [
            "tag": "vpndirect-geosite-category-ru",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/sing-box/rule-set-geosite/geosite-category-ru.srs",
            "http_client": httpClientTag,
            "update_interval": "24h",
        ],
        [
            "tag": "vpndirect-geoip-ru",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/sing-box/rule-set-geoip/geoip-ru.srs",
            "http_client": httpClientTag,
            "update_interval": "24h",
        ],
        [
            "tag": "vpndirect-geosite-ru-available-only-inside",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/sing-box/rule-set-geosite/geosite-ru-available-only-inside.srs",
            "http_client": httpClientTag,
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

        // Always scrub legacy `download_detour` so sing-box 1.14+ does not warn.
        sets = sets.map(migrateLegacyDownloadDetour)
        scrubLegacyGeoDownloadDetour(route: &route)

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

        let needsHTTPClient = enabled || sets.contains { ($0["type"] as? String) == "remote" }
        if needsHTTPClient {
            ensureSharedHTTPClient(root: &root, route: &route)
            // Point any remote set still missing http_client at the shared client.
            sets = sets.map { set in
                var next = set
                guard (next["type"] as? String) == "remote" else { return next }
                if next["http_client"] == nil {
                    next["http_client"] = httpClientTag
                }
                return next
            }
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

    /// `download_detour` → `http_client` tag/object (sing-box 1.14+). Always drops the legacy key.
    private static func migrateLegacyDownloadDetour(_ set: [String: Any]) -> [String: Any] {
        var next = set
        let legacy = next.removeValue(forKey: "download_detour") as? String
        if next["http_client"] == nil {
            if let legacy, !legacy.isEmpty {
                next["http_client"] = ["detour": legacy]
            } else if (next["type"] as? String) == "remote" {
                next["http_client"] = httpClientTag
            }
        }
        return next
    }

    private static func scrubLegacyGeoDownloadDetour(route: inout [String: Any]) {
        for key in ["geoip", "geosite"] {
            guard var block = route[key] as? [String: Any] else { continue }
            block.removeValue(forKey: "download_detour")
            route[key] = block
        }
    }

    /// Explicit shared client so remote rule-sets do not need legacy `download_detour`.
    /// Uses `direct` so rule-set files can download before the VPN tunnel is fully selected.
    private static func ensureSharedHTTPClient(root: inout [String: Any], route: inout [String: Any]) {
        var clients = root["http_clients"] as? [[String: Any]] ?? []
        clients.removeAll { ($0["tag"] as? String) == httpClientTag }
        clients.append([
            "tag": httpClientTag,
            "detour": "direct",
        ])
        root["http_clients"] = clients
        route["default_http_client"] = httpClientTag
    }
}
