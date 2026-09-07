import Foundation
import Libbox

/// Builds sing-box JSON from NormalizedSubscription (location groups + global auto).
/// WireGuard / AmneziaWG leaves go into top-level `endpoints`; other leaves into `outbounds`.
enum SingBoxGraphBuilder {
    /// Explicit product defaults when source config does not supply values.
    enum ProductDefaults {
        static let dnsServer = "1.1.1.1"
        static let dnsStrategy = "prefer_ipv4"
        static let tunMTUWithoutProtocolHint = 1500
        static let urltestProbe = "https://www.gstatic.com/generate_204"
        static let urltestInterval = "1m"
        static let urltestTolerance = 80
        static let urltestIdleTimeout = "30m"
        /// Product policy: RFC1918 stays direct unless source routing overrides (future).
        static let bypassPrivateNetworks = true
    }

    struct RejectedLeaf: Equatable {
        let name: String
        let protocolID: String
        let component: String
        let userReason: String
        let debugReason: String
        let topologyReferenced: Bool
    }

    struct GraphResult {
        let json: String
        let locationCount: Int
        let leafCount: Int
        let firstName: String?
        let rejected: [RejectedLeaf]
        let warnings: [String]
    }

    private struct BuiltLeaf {
        let node: NormalizedNode
        var object: [String: Any]
        let tag: String
        let isEndpoint: Bool
    }

    static func build(from subscription: NormalizedSubscription) throws -> GraphResult {
        var usedTags = Set<String>()
        var locationTags: [String] = []
        var leafTagCount = 0
        var outbounds: [[String: Any]] = []
        var endpoints: [[String: Any]] = []
        var rejected: [RejectedLeaf] = []
        var warnings: [String] = subscription.importWarnings
        warnings.append(contentsOf: VPNDirectRoutingHonesty.ignoredRoutingWarnings(for: subscription))

        /// Graph reference id (display name / xrayTag) → final leaf tag.
        var idToLeafTag: [String: String] = [:]

        var referencedNames = Set<String>()
        for location in subscription.locations {
            for ep in location.endpoints {
                if let d = ep.detour, !d.isEmpty { referencedNames.insert(d) }
                if let tag = ep.attributes["xrayTag"], !tag.isEmpty {
                    referencedNames.insert(tag)
                }
            }
            for mid in location.memberLocationIDs {
                referencedNames.insert(mid)
            }
        }

        // PASS 1 — build unique leaves once (shared across groups); assign provisional location tags.
        var sharedLeavesByName: [String: BuiltLeaf] = [:]
        var locationBuilt: [(location: NormalizedLocation, memberTags: [String])] = []
        // location id/name → assigned tag (for nested group refs)
        var locationIDToTag: [String: String] = [:]

        // Pre-assign location tags so nested members can resolve.
        for location in subscription.locations {
            let locationTag = VPNDirectTagFactory.uniqueTag(
                from: location.name,
                fallback: "loc-\(locationIDToTag.count + 1)",
                used: &usedTags
            )
            locationIDToTag[location.id] = locationTag
            locationIDToTag[location.name] = locationTag
        }

        for location in subscription.locations {
            var memberTags: [String] = []
            var locationRejects = 0

            for (entryIndex, endpoint) in location.endpoints.enumerated() {
                let sharedKey = endpoint.name
                if let existing = sharedLeavesByName[sharedKey] {
                    memberTags.append(existing.tag)
                    continue
                }

                let leaf: [String: Any]
                do {
                    leaf = try UniversalOutboundBuilder.build(from: endpoint)
                } catch {
                    let (component, detail) = classifyBuildError(error)
                    let topologyReferenced = referencedNames.contains(endpoint.name)
                        || referencedNames.contains(endpoint.attributes["xrayTag"] ?? "")
                        || endpoint.detour != nil
                        || location.strategy != .single
                        || !location.memberLocationIDs.isEmpty
                        || location.endpoints.count > 1
                    rejected.append(
                        RejectedLeaf(
                            name: endpoint.name,
                            protocolID: endpoint.protocolID.rawValue,
                            component: component,
                            userReason: detail,
                            debugReason: String(describing: error),
                            topologyReferenced: topologyReferenced
                        )
                    )
                    locationRejects += 1
                    if topologyReferenced {
                        throw VPNDirectCoreError.malformedConfig(
                            component: component,
                            detail: "rejected topology-referenced leaf '\(endpoint.name)': \(detail)"
                        )
                    }
                    warnings.append("dropped independent leaf '\(endpoint.name)': \(detail)")
                    continue
                }

                let leafTag = VPNDirectTagFactory.uniqueTag(
                    from: "n-\(endpoint.name)",
                    fallback: "leaf-\(sharedLeavesByName.count + 1)-\(entryIndex + 1)",
                    used: &usedTags
                )
                var tagged = leaf
                tagged["tag"] = leafTag
                registerIdentity(endpoint, tag: leafTag, into: &idToLeafTag)
                let built = BuiltLeaf(
                    node: endpoint,
                    object: tagged,
                    tag: leafTag,
                    isEndpoint: isWireGuardEndpoint(tagged)
                )
                sharedLeavesByName[sharedKey] = built
                memberTags.append(leafTag)
            }

            // Nested group members (Clash proxy-group → other groups).
            for mid in location.memberLocationIDs {
                guard let nestedTag = locationIDToTag[mid] else {
                    throw VPNDirectCoreError.malformedConfig(
                        component: "graph.group",
                        detail: "missing nested group '\(mid)' referenced by '\(location.name)'"
                    )
                }
                if nestedTag == locationIDToTag[location.id] {
                    throw VPNDirectCoreError.malformedConfig(
                        component: "graph.group",
                        detail: "group '\(location.name)' cannot reference itself"
                    )
                }
                memberTags.append(nestedTag)
            }

            if memberTags.isEmpty {
                if locationRejects > 0 || !location.endpoints.isEmpty || !location.memberLocationIDs.isEmpty {
                    warnings.append("location '\(location.name)' had no buildable members")
                }
                continue
            }
            leafTagCount += location.endpoints.count
            locationBuilt.append((location, memberTags))
        }

        // Detect cycles among nested location refs.
        try detectGroupCycles(subscription.locations)

        // PASS 2 — resolve detours (order-independent). Missing target is fatal.
        for key in Array(sharedLeavesByName.keys) {
            guard let detourName = sharedLeavesByName[key]?.node.detour, !detourName.isEmpty else { continue }
            guard let detourTag = resolveReference(detourName, in: idToLeafTag) else {
                throw VPNDirectCoreError.malformedConfig(
                    component: "graph.detour",
                    detail: "missing detour target '\(detourName)' for '\(sharedLeavesByName[key]!.node.name)'"
                )
            }
            var leaf = sharedLeavesByName[key]!
            leaf.object["detour"] = detourTag
            sharedLeavesByName[key] = leaf
        }

        // Emit each unique leaf once.
        for leaf in sharedLeavesByName.values.sorted(by: { $0.tag < $1.tag }) {
            if leaf.isEndpoint {
                endpoints.append(leaf.object)
            } else {
                outbounds.append(leaf.object)
            }
        }

        // PASS 3 — assemble location groups. Strategy decides graph type (never leaf count alone).
        for (location, memberTags) in locationBuilt {
            guard let locationTag = locationIDToTag[location.id] ?? locationIDToTag[location.name] else {
                continue
            }

            switch location.strategy {
            case .urltest:
                outbounds.append(
                    urltestOutbound(
                        tag: locationTag,
                        members: memberTags,
                        url: location.healthCheckURL,
                        interval: location.healthCheckInterval
                    )
                )

            case .select, .random:
                outbounds.append([
                    "type": "selector",
                    "tag": locationTag,
                    "outbounds": memberTags,
                ])

            case .fallback:
                // sing-box has no native "fallback" outbound; use urltest with source interval when present.
                outbounds.append(
                    urltestOutbound(
                        tag: locationTag,
                        members: memberTags,
                        url: location.healthCheckURL,
                        interval: location.healthCheckInterval
                    )
                )
                warnings.append(
                    "location '\(location.name)' strategy=fallback → urltest (Core has no native fallback outbound)"
                )

            case .single:
                // Never retag shared leaves — other groups may reference the same leaf tag.
                outbounds.append([
                    "type": "selector",
                    "tag": locationTag,
                    "outbounds": memberTags,
                ])
                if memberTags.count > 1 {
                    warnings.append(
                        "location '\(location.name)' strategy=single with \(memberTags.count) members → selector"
                    )
                }
            }

            locationTags.append(locationTag)
        }

        guard !locationTags.isEmpty else {
            if !rejected.isEmpty {
                let preview = rejected.prefix(5).map { "\($0.name):\($0.userReason)" }.joined(separator: "; ")
                throw VPNDirectCoreError.malformedConfig(
                    component: "graph",
                    detail: "no buildable locations; rejects: \(preview)"
                )
            }
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }

        // Global Auto uses semantic location roots — not every helper/detour leaf.
        let autoMembers = locationTags
        let selectorOutbounds = ["auto"] + locationTags
        let urlTest = urltestOutbound(tag: "auto", members: autoMembers)
        let selector: [String: Any] = [
            "type": "selector",
            "tag": "proxy",
            "outbounds": selectorOutbounds,
            "default": "auto",
        ]

        let tunMTU = resolvedTunnelMTU(endpoints: endpoints)
        let dnsServer = subscription.metadata.dnsRemoteServer ?? ProductDefaults.dnsServer
        let dnsStrategy = subscription.metadata.dnsStrategy ?? ProductDefaults.dnsStrategy
        let bypassPrivate = subscription.metadata.bypassPrivateNetworks ?? ProductDefaults.bypassPrivateNetworks
        if subscription.metadata.dnsRemoteServer == nil {
            warnings.append(
                "DNS remote server absent in subscription metadata; using product default \(ProductDefaults.dnsServer) (REQ-P081)."
            )
        }
        if subscription.metadata.dnsStrategy == nil {
            warnings.append(
                "DNS strategy absent; using product default \(ProductDefaults.dnsStrategy) (REQ-P082)."
            )
        }
        if subscription.metadata.bypassPrivateNetworks == nil, ProductDefaults.bypassPrivateNetworks {
            warnings.append(
                "Private-network bypass uses product default (RFC1918 → direct); source routing not applied (REQ-P084)."
            )
        }
        warnings.append(
            "URLTest probe defaults to \(ProductDefaults.urltestProbe) unless location.healthCheckURL is set (REQ-P116/P117)."
        )
        // REQ-P133: sing-box-lx Outbound(tag) falls back to endpoint.Get(tag), so WG endpoint tags
        // are valid selector/urltest members without a bridge outbound.
        var routeRules: [[String: Any]] = [
            ["action": "sniff"],
            [
                "protocol": ["dns"],
                "action": "hijack-dns",
            ],
        ]
        if bypassPrivate {
            routeRules.append([
                "ip_is_private": true,
                "outbound": "direct",
            ])
        }

        var config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
            ],
            "dns": [
                "servers": [
                    [
                        "type": "udp",
                        "tag": "dns-remote",
                        "server": dnsServer,
                    ],
                    [
                        "type": "local",
                        "tag": "dns-local",
                    ],
                ],
                "final": "dns-remote",
                "strategy": dnsStrategy,
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": ["172.19.0.1/30"],
                    "mtu": tunMTU,
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
                    "strategy": dnsStrategy,
                ],
                "rules": routeRules,
                "final": "proxy",
            ],
        ]
        if !endpoints.isEmpty {
            config["endpoints"] = endpoints
        }

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SubscriptionConfigBuilder.SubscriptionError.serializationFailed
        }

        // Canonical lifecycle: migrate → LibboxCheckConfig(FINAL) inside migrator → return exact checked JSON.
        let migrated = try SingBoxConfigMigrator.migrate(json)
        return GraphResult(
            json: migrated,
            locationCount: locationTags.count,
            leafCount: leafTagCount,
            firstName: subscription.name,
            rejected: rejected,
            warnings: warnings
        )
    }

    /// Share-link list → one location per node, then same graph.
    static func build(fromShareNodes nodes: [NormalizedNode]) throws -> GraphResult {
        let locations: [NormalizedLocation] = nodes.enumerated().map { index, node in
            NormalizedLocation(
                id: "share-\(index + 1)",
                name: node.name.isEmpty ? "Server \(index + 1)" : node.name,
                kind: .server,
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

    private static func urltestOutbound(
        tag: String,
        members: [String],
        url: String? = nil,
        interval: String? = nil
    ) -> [String: Any] {
        [
            "type": "urltest",
            "tag": tag,
            "outbounds": members,
            "url": url ?? ProductDefaults.urltestProbe,
            "interval": interval ?? ProductDefaults.urltestInterval,
            "tolerance": ProductDefaults.urltestTolerance,
            "idle_timeout": ProductDefaults.urltestIdleTimeout,
        ]
    }

    private static func detectGroupCycles(_ locations: [NormalizedLocation]) throws {
        var adjacency: [String: [String]] = [:]
        for loc in locations {
            let key = loc.id
            adjacency[key] = loc.memberLocationIDs.compactMap { mid in
                locations.first(where: { $0.id == mid || $0.name == mid })?.id
            }
        }
        var visiting = Set<String>()
        var visited = Set<String>()
        func dfs(_ node: String) throws {
            if visiting.contains(node) {
                throw VPNDirectCoreError.malformedConfig(
                    component: "graph.group",
                    detail: "cycle detected involving group '\(node)'"
                )
            }
            if visited.contains(node) { return }
            visiting.insert(node)
            for child in adjacency[node] ?? [] {
                try dfs(child)
            }
            visiting.remove(node)
            visited.insert(node)
        }
        for key in adjacency.keys {
            try dfs(key)
        }
    }

    private static func registerIdentity(
        _ endpoint: NormalizedNode,
        tag: String,
        into map: inout [String: String]
    ) {
        map[endpoint.name] = tag
        if let xrayTag = endpoint.attributes["xrayTag"], !xrayTag.isEmpty {
            map[xrayTag] = tag
        }
    }

    private static func resolveReference(_ name: String, in map: [String: String]) -> String? {
        map[name]
    }

    private static func resolvedTunnelMTU(endpoints: [[String: Any]]) -> Int {
        let mtus = endpoints.compactMap { $0["mtu"] as? Int }.filter { $0 > 0 }
        if let minMTU = mtus.min() {
            return minMTU
        }
        return ProductDefaults.tunMTUWithoutProtocolHint
    }

    private static func isWireGuardEndpoint(_ leaf: [String: Any]) -> Bool {
        let type = (leaf["type"] as? String)?.lowercased() ?? ""
        return type == "wireguard" || type == "amneziawg"
    }

    private static func classifyBuildError(_ error: Error) -> (String, String) {
        if case let VPNDirectCoreError.unsupportedFeature(component, detail) = error {
            return (component, detail)
        }
        if case let VPNDirectCoreError.malformedConfig(component, detail) = error {
            return (component, detail)
        }
        return ("builder", error.localizedDescription)
    }
}
