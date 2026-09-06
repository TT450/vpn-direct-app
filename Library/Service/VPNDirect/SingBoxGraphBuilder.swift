import Foundation
import Libbox

/// Builds sing-box JSON from NormalizedSubscription (location urltest + global auto).
enum SingBoxGraphBuilder {
    struct GraphResult {
        let json: String
        let locationCount: Int
        let leafCount: Int
        let firstName: String?
    }

    static func build(from subscription: NormalizedSubscription) throws -> GraphResult {
        var usedTags = Set<String>()
        var locationTags: [String] = []
        var allLeafTags: [String] = []
        var outbounds: [[String: Any]] = []
        /// Endpoint provisional name → final sing-box leaf tag (for detour rewrite).
        var nameToLeafTag: [String: String] = [:]

        for location in subscription.locations {
            var leafTags: [String] = []
            var leafOutbounds: [[String: Any]] = []

            for (entryIndex, endpoint) in location.endpoints.enumerated() {
                var outbound: [String: Any]
                do {
                    outbound = try UniversalOutboundBuilder.build(from: endpoint)
                } catch {
                    continue
                }
                let leafTag = VPNDirectTagFactory.uniqueTag(
                    from: "\(location.name)-n\(entryIndex + 1)",
                    fallback: "leaf-\(locationTags.count + 1)-\(entryIndex + 1)",
                    used: &usedTags
                )
                outbound["tag"] = leafTag
                if let detourName = endpoint.detour, !detourName.isEmpty {
                    // Temporarily store provisional detour name; resolve after all leaves tagged.
                    outbound["_vpndirect_detour_name"] = detourName
                }
                nameToLeafTag[endpoint.name] = leafTag
                leafTags.append(leafTag)
                leafOutbounds.append(outbound)
            }

            guard !leafTags.isEmpty else { continue }

            if location.strategy == .urltest || leafTags.count > 1 {
                let locationTag = VPNDirectTagFactory.uniqueTag(
                    from: location.name,
                    fallback: "loc-\(locationTags.count + 1)",
                    used: &usedTags
                )
                outbounds.append(contentsOf: leafOutbounds)
                outbounds.append([
                    "type": "urltest",
                    "tag": locationTag,
                    "outbounds": leafTags,
                    "url": "https://www.gstatic.com/generate_204",
                    "interval": "1m",
                    "tolerance": 80,
                    "idle_timeout": "30m",
                ])
                locationTags.append(locationTag)
                allLeafTags.append(contentsOf: leafTags)
            } else {
                var only = leafOutbounds[0]
                let locationTag = VPNDirectTagFactory.uniqueTag(
                    from: location.name,
                    fallback: leafTags[0],
                    used: &usedTags
                )
                only["tag"] = locationTag
                only.removeValue(forKey: "_vpndirect_detour_name")
                if let detourName = location.endpoints.first?.detour,
                   let detourTag = nameToLeafTag[detourName]
                {
                    only["detour"] = detourTag
                }
                outbounds.append(only)
                locationTags.append(locationTag)
                allLeafTags.append(locationTag)
                nameToLeafTag[location.endpoints[0].name] = locationTag
            }
        }

        // Resolve detours on multi-leaf locations.
        for index in outbounds.indices {
            guard let provisional = outbounds[index].removeValue(forKey: "_vpndirect_detour_name") as? String,
                  let detourTag = nameToLeafTag[provisional]
            else { continue }
            outbounds[index]["detour"] = detourTag
        }

        guard !locationTags.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }

        let autoMembers = allLeafTags.isEmpty ? locationTags : allLeafTags
        let selectorOutbounds = ["auto"] + locationTags
        let urlTest: [String: Any] = [
            "type": "urltest",
            "tag": "auto",
            "outbounds": autoMembers,
            "url": "https://www.gstatic.com/generate_204",
            "interval": "1m",
            "tolerance": 80,
            "idle_timeout": "30m",
        ]
        let selector: [String: Any] = [
            "type": "selector",
            "tag": "proxy",
            "outbounds": selectorOutbounds,
            "default": "auto",
        ]

        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
            ],
            "dns": [
                "servers": [
                    [
                        "type": "udp",
                        "tag": "dns-remote",
                        "server": "1.1.1.1",
                    ],
                    [
                        "type": "local",
                        "tag": "dns-local",
                    ],
                ],
                "final": "dns-remote",
                "strategy": "prefer_ipv4",
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": ["172.19.0.1/30"],
                    "mtu": 9000,
                    "auto_route": true,
                    "strict_route": true,
                    "stack": "gvisor",
                ],
            ],
            "outbounds": [selector, urlTest] + outbounds + [[
                "type": "direct",
                "tag": "direct",
            ]],
            "route": [
                "auto_detect_interface": true,
                "default_domain_resolver": [
                    "server": "dns-remote",
                    "strategy": "prefer_ipv4",
                ],
                "rules": [
                    ["action": "sniff"],
                    [
                        "protocol": ["dns"],
                        "action": "hijack-dns",
                    ],
                    [
                        "ip_is_private": true,
                        "outbound": "direct",
                    ],
                ],
                "final": "proxy",
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SubscriptionConfigBuilder.SubscriptionError.serializationFailed
        }

        var error: NSError?
        LibboxCheckConfig(json, &error)
        if let error {
            throw error
        }

        let migrated = try SingBoxConfigMigrator.migrate(json)
        return GraphResult(
            json: migrated,
            locationCount: locationTags.count,
            leafCount: allLeafTags.count,
            firstName: subscription.name
        )
    }

    /// Share-link list → one location per node, then same graph.
    static func build(fromShareNodes nodes: [NormalizedNode]) throws -> GraphResult {
        let locations: [NormalizedLocation] = nodes.enumerated().map { index, node in
            NormalizedLocation(
                id: "share-\(index + 1)",
                name: node.name.isEmpty ? "Server \(index + 1)" : node.name,
                kind: .country,
                strategy: .single,
                endpoints: [node]
            )
        }
        guard !locations.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }
        return try build(from: NormalizedSubscription(
            name: locations.first?.name,
            locations: locations
        ))
    }
}
