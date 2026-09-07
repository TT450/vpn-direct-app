import Foundation
import Libbox

/// Builds sing-box JSON from NormalizedSubscription.
/// WireGuard / AmneziaWG leaves are emitted as top-level `endpoints`; proxy leaves as `outbounds`.
enum SingBoxGraphBuilder {
    enum ProductDefaults {
        static let dnsServer = "1.1.1.1"
        static let dnsStrategy = "prefer_ipv4"
        static let tunMTUWithoutProtocolHint = 1500
        static let urltestProbe = "https://www.gstatic.com/generate_204"
        static let urltestInterval = "1m"
        static let urltestTolerance = 80
        static let urltestIdleTimeout = "30m"
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
        var outbounds: [[String: Any]] = []
        var endpoints: [[String: Any]] = []
        var rejected: [RejectedLeaf] = []
        var warnings = subscription.importWarnings
        warnings.append(contentsOf: VPNDirectRoutingHonesty.ignoredRoutingWarnings(for: subscription))

        // Display names are NOT identities. A reference may resolve only when exactly one built leaf owns it.
        var referenceCandidates: [String: [String]] = [:]
        func registerReference(_ reference: String?, tag: String) {
            guard let reference, !reference.isEmpty else { return }
            var values = referenceCandidates[reference] ?? []
            if !values.contains(tag) { values.append(tag) }
            referenceCandidates[reference] = values
        }
        func resolveReference(_ reference: String) throws -> String {
            let candidates = referenceCandidates[reference] ?? []
            guard !candidates.isEmpty else {
                throw VPNDirectCoreError.malformedConfig(
                    component: "graph.reference",
                    detail: "missing topology target '\(reference)'"
                )
            }
            guard candidates.count == 1 else {
                throw VPNDirectCoreError.malformedConfig(
                    component: "graph.reference",
                    detail: "ambiguous topology target '\(reference)' resolves to \(candidates.count) leaves"
                )
            }
            return candidates[0]
        }

        var referencedNames = Set<String>()
        for location in subscription.locations {
            for endpoint in location.endpoints {
                if let detour = endpoint.detour, !detour.isEmpty { referencedNames.insert(detour) }
                if let xrayTag = endpoint.attributes["xrayTag"], !xrayTag.isEmpty { referencedNames.insert(xrayTag) }
            }
            for member in location.memberLocationIDs { referencedNames.insert(member) }
        }

        // Pre-assign every location tag so nested groups are order-independent.
        var locationIDToTag: [String: String] = [:]
        var ambiguousLocationNames = Set<String>()
        for (index, location) in subscription.locations.enumerated() {
            let tag = VPNDirectTagFactory.uniqueTag(
                from: location.id.isEmpty ? location.name : location.id,
                fallback: "loc-\(index + 1)",
                used: &usedTags
            )
            if !location.id.isEmpty { locationIDToTag[location.id] = tag }
            if let existing = locationIDToTag[location.name], existing != tag {
                ambiguousLocationNames.insert(location.name)
            } else if !location.name.isEmpty {
                locationIDToTag[location.name] = tag
            }
        }
        for name in ambiguousLocationNames { locationIDToTag.removeValue(forKey: name) }

        var builtLeaves: [BuiltLeaf] = []
        var locationBuilt: [(location: NormalizedLocation, memberTags: [String])] = []

        // PASS 1: build every endpoint instance exactly once. Never deduplicate by display name.
        for (locationIndex, location) in subscription.locations.enumerated() {
            var memberTags: [String] = []
            var locationRejects = 0

            for (entryIndex, endpoint) in location.endpoints.enumerated() {
                let leaf: [String: Any]
                do {
                    leaf = try UniversalOutboundBuilder.build(from: endpoint)
                } catch {
                    let (component, detail) = classifyBuildError(error)
                    let xrayTag = endpoint.attributes["xrayTag"] ?? ""
                    let topologyReferenced = referencedNames.contains(endpoint.name)
                        || (!xrayTag.isEmpty && referencedNames.contains(xrayTag))
                        || endpoint.detour != nil
                        || location.strategy != .single
                        || !location.memberLocationIDs.isEmpty
                        || location.endpoints.count > 1
                    rejected.append(RejectedLeaf(
                        name: endpoint.name,
                        protocolID: endpoint.protocolID.rawValue,
                        component: component,
                        userReason: detail,
                        debugReason: String(describing: error),
                        topologyReferenced: topologyReferenced
                    ))
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

                let stableSourceID = endpoint.attributes["xrayTag"].flatMap { $0.isEmpty ? nil : $0 }
                    ?? "\(location.id.isEmpty ? "loc-\(locationIndex + 1)" : location.id)/\(entryIndex)"
                let leafTag = VPNDirectTagFactory.uniqueTag(
                    from: "n-\(stableSourceID)",
                    fallback: "leaf-\(locationIndex + 1)-\(entryIndex + 1)",
                    used: &usedTags
                )
                var tagged = leaf
                tagged["tag"] = leafTag
                let built = BuiltLeaf(
                    node: endpoint,
                    object: tagged,
                    tag: leafTag,
                    isEndpoint: isWireGuardEndpoint(tagged)
                )
                builtLeaves.append(built)
                memberTags.append(leafTag)

                // Authoritative producer tag/internal scoped ID first; display name only as compatibility reference.
                registerReference(endpoint.attributes["xrayTag"], tag: leafTag)
                registerReference("\(location.id)/\(entryIndex)", tag: leafTag)
                registerReference(endpoint.name, tag: leafTag)
            }

            for memberID in location.memberLocationIDs {
                guard let nestedTag = locationIDToTag[memberID] else {
                    throw VPNDirectCoreError.malformedConfig(
                        component: "graph.group",
                        detail: "missing or ambiguous nested group '\(memberID)' referenced by '\(location.name)'"
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
            locationBuilt.append((location, memberTags))
        }

        try detectGroupCycles(subscription.locations)

        // PASS 2: resolve all detours after all identities exist. Missing/ambiguous target is fatal.
        for index in builtLeaves.indices {
            guard let detour = builtLeaves[index].node.detour, !detour.isEmpty else { continue }
            builtLeaves[index].object["detour"] = try resolveReference(detour)
        }

        for leaf in builtLeaves.sorted(by: { $0.tag < $1.tag }) {
            if leaf.isEndpoint { endpoints.append(leaf.object) }
            else { outbounds.append(leaf.object) }
        }

        // PASS 3: emit only strategies that have faithful Core semantics.
        var locationTags: [String] = []
        for (location, memberTags) in locationBuilt {
            guard let locationTag = locationIDToTag[location.id] ?? locationIDToTag[location.name] else {
                throw VPNDirectCoreError.malformedConfig(
                    component: "graph.group",
                    detail: "missing or ambiguous group identity for '\(location.name)'"
                )
            }
            switch location.strategy {
            case .urltest:
                outbounds.append(urltestOutbound(
                    tag: locationTag,
                    members: memberTags,
                    url: location.healthCheckURL,
                    interval: location.healthCheckInterval
                ))
            case .select:
                outbounds.append([
                    "type": "selector",
                    "tag": locationTag,
                    "outbounds": memberTags,
                ])
            case .random:
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "graph.strategy.random",
                    detail: "Random group cannot be represented faithfully by selector/urltest in the pinned Core"
                )
            case .fallback:
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "graph.strategy.fallback",
                    detail: "Fallback group cannot be replaced by latency urltest without changing semantics"
                )
            case .single:
                guard memberTags.count == 1 else {
                    throw VPNDirectCoreError.malformedConfig(
                        component: "graph.strategy.single",
                        detail: "Single location '\(location.name)' contains \(memberTags.count) members"
                    )
                }
                // Keep a semantic root so Global Auto never bypasses the location abstraction.
                outbounds.append([
                    "type": "selector",
                    "tag": locationTag,
                    "outbounds": memberTags,
                    "default": memberTags[0],
                ])
            }
            locationTags.append(locationTag)
        }

        guard !locationTags.isEmpty else {
            if !rejected.isEmpty {
                let preview = rejected.prefix(5).map { "\($0.name):\($0.userReason)" }.joined(separator: "; ")
                throw VPNDirectCoreError.malformedConfig(component: "graph", detail: "no buildable locations; rejects: \(preview)")
            }
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }

        let urlTest = urltestOutbound(tag: "auto", members: locationTags)
        let selector: [String: Any] = [
            "type": "selector",
            "tag": "proxy",
            "outbounds": ["auto"] + locationTags,
            "default": "auto",
        ]

        let tunMTU = resolvedTunnelMTU(endpoints: endpoints)
        let dnsServer = subscription.metadata.dnsRemoteServer ?? ProductDefaults.dnsServer
        let dnsStrategy = subscription.metadata.dnsStrategy ?? ProductDefaults.dnsStrategy
        let bypassPrivate = subscription.metadata.bypassPrivateNetworks ?? ProductDefaults.bypassPrivateNetworks
        if subscription.metadata.dnsRemoteServer == nil {
            warnings.append("DNS remote server absent; using product default \(ProductDefaults.dnsServer) (REQ-P081).")
        }
        if subscription.metadata.dnsStrategy == nil {
            warnings.append("DNS strategy absent; using product default \(ProductDefaults.dnsStrategy) (REQ-P082).")
        }
        if subscription.metadata.bypassPrivateNetworks == nil, ProductDefaults.bypassPrivateNetworks {
            warnings.append("Private-network bypass uses product default; source routing is not applied (REQ-P084).")
        }
        warnings.append("URLTest probe defaults to \(ProductDefaults.urltestProbe) unless source health check is set (REQ-P116/P117).")

        var routeRules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": ["dns"], "action": "hijack-dns"],
        ]
        if bypassPrivate { routeRules.append(["ip_is_private": true, "outbound": "direct"]) }

        var config: [String: Any] = [
            "log": ["level": "info", "timestamp": true],
            "dns": [
                "servers": [
                    ["type": "udp", "tag": "dns-remote", "server": dnsServer],
                    ["type": "local", "tag": "dns-local"],
                ],
                "final": "dns-remote",
                "strategy": dnsStrategy,
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.19.0.1/30"],
                "mtu": tunMTU,
                "auto_route": true,
                "strict_route": true,
                "stack": "gvisor",
            ]],
            "outbounds": [selector, urlTest] + outbounds + [["type": "direct", "tag": "direct"]],
            "route": [
                "auto_detect_interface": true,
                "default_domain_resolver": ["server": "dns-remote", "strategy": dnsStrategy],
                "rules": routeRules,
                "final": "proxy",
            ],
        ]
        if !endpoints.isEmpty { config["endpoints"] = endpoints }

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SubscriptionConfigBuilder.SubscriptionError.serializationFailed
        }

        // Canonical lifecycle: migrate and validate the exact final config that will be launched.
        let migrated = try SingBoxConfigMigrator.migrate(json)
        return GraphResult(
            json: migrated,
            locationCount: locationTags.count,
            leafCount: builtLeaves.count,
            firstName: subscription.name,
            rejected: rejected,
            warnings: warnings
        )
    }

    static func build(fromShareNodes nodes: [NormalizedNode]) throws -> GraphResult {
        let locations = nodes.enumerated().map { index, node in
            NormalizedLocation(
                id: "share-\(index + 1)",
                name: node.name.isEmpty ? "Server \(index + 1)" : node.name,
                kind: .server,
                strategy: .single,
                endpoints: [node]
            )
        }
        guard !locations.isEmpty else { throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks }
        return try build(from: NormalizedSubscription(name: locations.first?.name, locations: locations))
    }

    private static func urltestOutbound(tag: String, members: [String], url: String? = nil, interval: String? = nil) -> [String: Any] {
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
        for location in locations {
            adjacency[location.id] = location.memberLocationIDs.compactMap { member in
                locations.first(where: { $0.id == member || $0.name == member })?.id
            }
        }
        var visiting = Set<String>()
        var visited = Set<String>()
        func dfs(_ node: String) throws {
            if visiting.contains(node) {
                throw VPNDirectCoreError.malformedConfig(component: "graph.group", detail: "cycle detected involving group '\(node)'")
            }
            if visited.contains(node) { return }
            visiting.insert(node)
            for child in adjacency[node] ?? [] { try dfs(child) }
            visiting.remove(node)
            visited.insert(node)
        }
        for key in adjacency.keys { try dfs(key) }
    }

    private static func resolvedTunnelMTU(endpoints: [[String: Any]]) -> Int {
        let mtus = endpoints.compactMap { $0["mtu"] as? Int }.filter { $0 > 0 }
        return mtus.min() ?? ProductDefaults.tunMTUWithoutProtocolHint
    }

    private static func isWireGuardEndpoint(_ leaf: [String: Any]) -> Bool {
        let type = (leaf["type"] as? String)?.lowercased() ?? ""
        return type == "wireguard" || type == "amneziawg"
    }

    private static func classifyBuildError(_ error: Error) -> (String, String) {
        if case let VPNDirectCoreError.unsupportedFeature(component, detail) = error { return (component, detail) }
        if case let VPNDirectCoreError.malformedConfig(component, detail) = error { return (component, detail) }
        return ("builder", error.localizedDescription)
    }
}
