import Foundation
import Libbox

/// Migrates sing-box configs to 1.12+ format (domain resolver) so Libbox 1.13+ does not warn.
public enum SingBoxConfigMigrator {
    public static func migrate(_ json: String) throws -> String {
        guard let data = json.data(using: .utf8),
              var root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return json
        }

        migrateLegacyDNS(&root)
        ensureDNSServerTags(&root)
        let resolverTag = pickResolverTag(from: root)
        migrateDomainStrategy(&root, resolverTag: resolverTag)
        addDomainResolverToDialFields(&root, resolverTag: resolverTag)
        addDefaultDomainResolverIfNeeded(&root, resolverTag: resolverTag)
        migrateTunStack(&root)

        let migratedData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        guard let migrated = String(data: migratedData, encoding: .utf8) else {
            return json
        }

        var error: NSError?
        LibboxCheckConfig(migrated, &error)
        if let error {
            throw error
        }
        return migrated
    }

    private static func migrateLegacyDNS(_ root: inout [String: Any]) {
        guard var dns = root["dns"] as? [String: Any] else { return }

        if var servers = dns["servers"] as? [[String: Any]] {
            for index in servers.indices {
                if servers[index]["server"] == nil, let address = servers[index]["address"] as? String {
                    servers[index].removeValue(forKey: "address")
                    if (servers[index]["type"] as? String)?.isEmpty != false {
                        servers[index]["type"] = address.contains(":") ? "tcp" : "udp"
                    }
                    servers[index]["server"] = address
                }
                if servers[index]["tag"] == nil {
                    let type = (servers[index]["type"] as? String) ?? "server"
                    servers[index]["tag"] = "dns-\(type)-\(index + 1)"
                }
            }
            dns["servers"] = servers
        }

        if var rules = dns["rules"] as? [[String: Any]] {
            rules.removeAll { rule in
                rule["outbound"] != nil || rule["geosite"] != nil && rule["server"] != nil
            }
            if rules.isEmpty {
                dns.removeValue(forKey: "rules")
            } else {
                dns["rules"] = rules
            }
        }

        root["dns"] = dns
    }

    private static func ensureDNSServerTags(_ root: inout [String: Any]) {
        var dns = root["dns"] as? [String: Any] ?? [:]
        var servers = dns["servers"] as? [[String: Any]] ?? []

        if servers.isEmpty {
            servers = [
                ["type": "local", "tag": "dns-local"],
            ]
        }

        var hasLocal = false
        for index in servers.indices {
            if servers[index]["tag"] == nil {
                let type = (servers[index]["type"] as? String) ?? "server"
                servers[index]["tag"] = "dns-\(type)-\(index + 1)"
            }
            if servers[index]["tag"] as? String == "dns-local" || servers[index]["tag"] as? String == "local" {
                hasLocal = true
            }
        }

        if !hasLocal {
            servers.insert(["type": "local", "tag": "dns-local"], at: 0)
        }

        dns["servers"] = servers
        root["dns"] = dns
    }

    private static func pickResolverTag(from root: [String: Any]) -> String {
        guard let dns = root["dns"] as? [String: Any],
              let servers = dns["servers"] as? [[String: Any]]
        else {
            return "dns-local"
        }

        let tags = servers.compactMap { $0["tag"] as? String }
        if tags.contains("dns-local") { return "dns-local" }
        if tags.contains("local") { return "local" }
        if tags.contains("dns-remote") { return "dns-remote" }
        return tags.first ?? "dns-local"
    }

    private static func addDefaultDomainResolverIfNeeded(_ root: inout [String: Any], resolverTag: String) {
        var route = root["route"] as? [String: Any] ?? [:]
        if route["default_domain_resolver"] != nil {
            root["route"] = route
            return
        }

        route["default_domain_resolver"] = [
            "server": resolverTag,
            "strategy": "prefer_ipv4",
        ]
        root["route"] = route
    }

    private static func migrateDomainStrategy(_ root: inout [String: Any], resolverTag: String) {
        if var outbounds = root["outbounds"] as? [[String: Any]] {
            for index in outbounds.indices {
                migrateDialFields(&outbounds[index], resolverTag: resolverTag)
            }
            root["outbounds"] = outbounds
        }

        if var inbounds = root["inbounds"] as? [[String: Any]] {
            for index in inbounds.indices {
                migrateDialFields(&inbounds[index], resolverTag: resolverTag)
            }
            root["inbounds"] = inbounds
        }

        if var endpoints = root["endpoints"] as? [[String: Any]] {
            for index in endpoints.indices {
                migrateDialFields(&endpoints[index], resolverTag: resolverTag)
            }
            root["endpoints"] = endpoints
        }
    }

    private static func addDomainResolverToDialFields(_ root: inout [String: Any], resolverTag: String) {
        if var outbounds = root["outbounds"] as? [[String: Any]] {
            for index in outbounds.indices {
                addDomainResolverIfNeeded(&outbounds[index], resolverTag: resolverTag)
            }
            root["outbounds"] = outbounds
        }

        if var inbounds = root["inbounds"] as? [[String: Any]] {
            for index in inbounds.indices {
                addDomainResolverIfNeeded(&inbounds[index], resolverTag: resolverTag)
            }
            root["inbounds"] = inbounds
        }

        if var endpoints = root["endpoints"] as? [[String: Any]] {
            for index in endpoints.indices {
                addDomainResolverIfNeeded(&endpoints[index], resolverTag: resolverTag)
            }
            root["endpoints"] = endpoints
        }
    }

    private static func migrateDialFields(_ fields: inout [String: Any], resolverTag: String) {
        guard fields["domain_resolver"] == nil,
              let strategy = fields.removeValue(forKey: "domain_strategy") as? String,
              !strategy.isEmpty
        else { return }

        fields["domain_resolver"] = [
            "server": resolverTag,
            "strategy": strategy,
        ]
    }

    private static let proxyOutboundTypes: Set<String> = [
        "vless", "vmess", "trojan", "shadowsocks", "socks", "http", "hysteria", "hysteria2",
        "tuic", "wireguard", "ssh", "naive", "anytls",
    ]

    /// sing-tun: `system` / `mixed` stacks cannot be used with includeAllNetworks (kill switch).
    private static func migrateTunStack(_ root: inout [String: Any]) {
        guard var inbounds = root["inbounds"] as? [[String: Any]] else { return }
        for index in inbounds.indices {
            guard (inbounds[index]["type"] as? String) == "tun" else { continue }
            let stack = (inbounds[index]["stack"] as? String)?.lowercased() ?? "system"
            if stack == "system" || stack == "mixed" {
                inbounds[index]["stack"] = "gvisor"
            }
        }
        root["inbounds"] = inbounds
    }

    public static func migrateAllStoredProfiles() async {
        guard let profiles = try? await ProfileManager.list() else { return }
        for profile in profiles {
            _ = try? await profile.readAsync()
        }
    }

    private static func addDomainResolverIfNeeded(_ fields: inout [String: Any], resolverTag: String) {
        guard fields["domain_resolver"] == nil else { return }

        let type = (fields["type"] as? String)?.lowercased() ?? ""
        if proxyOutboundTypes.contains(type) {
            fields["domain_resolver"] = [
                "server": resolverTag,
                "strategy": "prefer_ipv4",
            ]
            return
        }

        guard let server = fields["server"] as? String, isHostname(server) else { return }

        fields["domain_resolver"] = [
            "server": resolverTag,
            "strategy": "prefer_ipv4",
        ]
    }

    private static func isHostname(_ value: String) -> Bool {
        if value.isEmpty { return false }
        if value.contains(":") { return false }
        if value.contains(where: { $0.isLetter }) { return true }
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return true }
        return !parts.allSatisfy { part in
            guard let number = Int(part), number >= 0, number <= 255 else { return false }
            return true
        }
    }
}
