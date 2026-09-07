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
        var builtLeafCount = 0
        var outbounds: [[String: Any]] = []
        /// Endpoint provisional reference name → final sing-box selectable tag.
        /// This is still a compatibility bridge until normalized graph IDs replace display-name references.
        var nameToLeafTag: [String: String] = [:]

        for location in subscription.locations {
            var leafTags: [String] = []
            var leafOutbounds: [[String: Any]] = []

            for (entryIndex, endpoint) in location.endpoints.enumerated() {
                // Never silently drop a node that failed to build. A topology-aware partial-import
                // policy belongs above this layer; the production graph itself must be fail-closed.
                var outbound = try UniversalOutboundBuilder.build(from: endpoint)
                let leafTag = VPNDirectTagFactory.uniqueTag(
                    from: "\(location.id)-n\(entryIndex + 1)",
                    fallback: "leaf-\(locationTags.count + 1)-\(entryIndex + 1)",
                    used: &usedTags
                )
                outbound["tag"] = leafTag
                if let detourName = endpoint.detour, !detourName.isEmpty {
                    // Resolve only after every node has a final tag so forward references are valid.
                    outbound["_vpndirect_detour_name"] = detourName
                }
                nameToLeafTag[endpoint.name] = leafTag
                leafTags.append(leafTag)
                leafOutbounds.append(outbound)
                builtLeafCount += 1
            }

            guard !leafTags.isEmpty else { continue }

            switch location.strategy {
            case .urltest:
                let locationTag = VPNDirectTagFactory.uniqueTag(
                    from: location.id.isEmpty ? location.name : location.id,
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

            case .single:
                guard leafOutbounds.count == 1 else {
                    throw NSError(
                        domain: "VPNDirect.SingBoxGraphBuilder",
                        code: 1001,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Location '\(location.name)' is marked single but contains \(leafOutbounds.count) endpoints"
                        ]
                    )
                }
                var only = leafOutbounds[0]
                let locationTag = VPNDirectTagFactory.uniqueTag(
                    from: location.id.isEmpty ? location.name : location.id,
                    fallback: leafTags[0],
                    used: &usedTags
                )
                only["tag"] = locationTag
                outbounds.append(only)
                locationTags.append(locationTag)
                nameToLeafTag[location.endpoints[0].name] = locationTag
            }
        }

        // Resolve all detours in a second pass, including single-node locations.
        // Missing references are connection-critical and must never disappear silently.
        for index in outbounds.indices {
            guard let provisional = outbounds[index].removeValue(forKey: "_vpndirect_detour_name") as? String else {
                continue
            }
            guard let detourTag = nameToLeafTag[provisional] else {
                throw NSError(
                    domain: "VPNDirect.SingBoxGraphBuilder",
                    code: 1002,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Missing detour target '\(provisional)'"
                    ]
                )
            }
            outbounds[index]["detour"] = detourTag
        }

        guard !locationTags.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }

        // Global Auto operates on semantic selectable roots, not every helper/leaf node.
        let selectorOutbounds = ["auto"] + locationTags
        let urlTest: [String: Any] = [
            "type": "urltest",
            "tag": "auto",
            "outbounds": locationTags,
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

        // The exact JSON that will be returned/launched must be the JSON Core validates.
        let migrated = try SingBoxConfigMigrator.migrate(json)
        var error: NSError?
        LibboxCheckConfig(migrated, &error)
        if let error {
            throw error
        }

        return GraphResult(
            json: migrated,
            locationCount: locationTags.count,
            leafCount: builtLeafCount,
            firstName: subscription.name
        )
    }

    /// Share-link list → one selectable group per node, then same graph.
    static func build(fromShareNodes nodes: [NormalizedNode]) throws -> GraphResult {
        let locations: [NormalizedLocation] = nodes.enumerated().map { index, node in
            NormalizedLocation(
                id: "share-\(index + 1)",
                name: node.name.isEmpty ? "Server \(index + 1)" : node.name,
                kind: .group,
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
