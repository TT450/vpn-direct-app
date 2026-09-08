import Foundation

/// Injects sing-box `rule_set` rules so Russian domains/IPs go `direct` (no VPN).
/// Same rule URLs as TheTochka. On Libbox 1.14 use ONLY `http_client` (not `download_detour`) —
/// emitting both causes: "http_client is conflict with deprecated download_detour field".
public enum RussianBypassRouting {
    private static let managedTags = [
        "vpndirect-geosite-category-ru",
        "vpndirect-geoip-ru",
        "vpndirect-geosite-ru-available-only-inside",
    ]

    private static let httpClientTag = "vpndirect-ruleset-http"

    private static func makeRuleSets() -> [[String: Any]] {
        [
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
    }

    public static func apply(to json: String, enabled: Bool) -> String {
        guard let data = json.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return json
        }

        ensureUsableDirectOutbound(root: &root)

        var route = root["route"] as? [String: Any] ?? [:]
        var sets = route["rule_set"] as? [[String: Any]] ?? []
        var rules = route["rules"] as? [[String: Any]] ?? []

        sets.removeAll { set in
            guard let tag = set["tag"] as? String else { return false }
            return managedTags.contains(tag)
                || tag.hasPrefix("aladdin-geosite")
                || tag.hasPrefix("aladdin-geoip")
        }
        rules.removeAll { rule in
            if let tag = rule["rule_set"] as? String {
                return managedTags.contains(tag) || tag.hasPrefix("aladdin-")
            }
            if let tags = rule["rule_set"] as? [String] {
                return tags.contains(where: { managedTags.contains($0) || $0.hasPrefix("aladdin-") })
            }
            return false
        }

        // Always strip deprecated download_detour — conflicts with http_client on 1.14.
        sets = sets.map { set in
            var next = set
            next.removeValue(forKey: "download_detour")
            return next
        }
        for key in ["geoip", "geosite"] {
            guard var block = route[key] as? [String: Any] else { continue }
            block.removeValue(forKey: "download_detour")
            route[key] = block
        }

        let downloadVia = preferredDownloadDetour(root: root)

        if enabled {
            if downloadVia == "direct" {
                // No proxy outbound — skip injection rather than break dial.
                root.removeValue(forKey: "http_clients")
                route.removeValue(forKey: "default_http_client")
            } else {
                ensureSharedHTTPClient(root: &root, route: &route, detour: downloadVia)
                sets.append(contentsOf: makeRuleSets())
                let insertIndex = rules.firstIndex { rule in
                    (rule["ip_is_private"] as? Bool) == true
                }.map { $0 + 1 } ?? rules.count
                rules.insert(
                    [
                        "rule_set": managedTags,
                        "outbound": "direct",
                    ],
                    at: min(insertIndex, rules.count)
                )
            }
        } else {
            root.removeValue(forKey: "http_clients")
            route.removeValue(forKey: "default_http_client")
            sets = sets.map { set in
                var next = set
                next.removeValue(forKey: "http_client")
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

    private static func preferredDownloadDetour(root: [String: Any]) -> String {
        let outbounds = root["outbounds"] as? [[String: Any]] ?? []
        let tags = Set(outbounds.compactMap { $0["tag"] as? String })
        if tags.contains("proxy") { return "proxy" }
        if tags.contains("auto") { return "auto" }
        return "direct"
    }

    private static func ensureUsableDirectOutbound(root: inout [String: Any]) {
        var outbounds = root["outbounds"] as? [[String: Any]] ?? []
        if let idx = outbounds.firstIndex(where: { ($0["tag"] as? String) == "direct" }) {
            if (outbounds[idx]["type"] as? String) != "direct" {
                outbounds[idx] = ["type": "direct", "tag": "direct"]
            }
        } else {
            outbounds.append(["type": "direct", "tag": "direct"])
        }
        root["outbounds"] = outbounds
    }

    private static func ensureSharedHTTPClient(root: inout [String: Any], route: inout [String: Any], detour: String) {
        var clients = root["http_clients"] as? [[String: Any]] ?? []
        clients.removeAll { ($0["tag"] as? String) == httpClientTag }
        clients.append([
            "tag": httpClientTag,
            "detour": detour,
        ])
        root["http_clients"] = clients
        route["default_http_client"] = httpClientTag
    }
}
