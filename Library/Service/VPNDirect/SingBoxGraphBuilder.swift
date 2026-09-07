import Foundation
import Libbox

/// Builds the exact final sing-box JSON that is handed to Libbox.
enum SingBoxGraphBuilder {
    struct GraphResult {
        let json: String
        let locationCount: Int
        let leafCount: Int
        let firstName: String?
    }

    private enum BuiltLeaf {
        case outbound([String: Any])
        case endpoint([String: Any])

        var object: [String: Any] {
            get {
                switch self {
                case .outbound(let object), .endpoint(let object): return object
                }
            }
            set {
                switch self {
                case .outbound: self = .outbound(newValue)
                case .endpoint: self = .endpoint(newValue)
                }
            }
        }
    }

    static func build(from subscription: NormalizedSubscription) throws -> GraphResult {
        var usedTags = Set<String>()
        var locationTags: [String] = []
        var builtLeafCount = 0
        var outbounds: [[String: Any]] = []
        var endpoints: [[String: Any]] = []

        // Compatibility reference map. Display-name identity is still being migrated to stable
        // graph IDs; duplicate names are rejected instead of silently overwriting the target.
        var referenceToTag: [String: String] = [:]
        var duplicateReferences = Set<String>()

        func registerReference(_ reference: String, tag: String) {
            guard !reference.isEmpty else { return }
            if let existing = referenceToTag[reference], existing != tag {
                duplicateReferences.insert(reference)
            } else {
                referenceToTag[reference] = tag
            }
        }

        for location in subscription.locations {
            var leafTags: [String] = []
            var leaves: [BuiltLeaf] = []

            for (entryIndex, node) in location.endpoints.enumerated() {
                let leafTag = VPNDirectTagFactory.uniqueTag(
                    from: "\(location.id)-n\(entryIndex + 1)",
                    fallback: "leaf-\(locationTags.count + 1)-\(entryIndex + 1)",
                    used: &usedTags
                )

                var built: BuiltLeaf
                if node.protocolID == .wireguard || node.protocolID == .amneziawg {
                    guard let model = node.wireguardEndpoint else {
                        throw VPNDirectCoreError.malformedConfig(
                            component: "wireguard",
                            detail: "WireGuard/AWG node is missing typed endpoint model"
                        )
                    }
                    built = .endpoint(try model.endpointJSON(tag: leafTag))
                } else {
                    var outbound = try UniversalOutboundBuilder.build(from: node)
                    outbound["tag"] = leafTag
                    built = .outbound(outbound)
                }

                if let detourName = node.detour, !detourName.isEmpty {
                    var object = built.object
                    object["_vpndirect_detour_ref"] = detourName
                    built.object = object
                }

                registerReference(node.name, tag: leafTag)
                registerReference("\(location.id)/\(entryIndex)", tag: leafTag)
                leafTags.append(leafTag)
                leaves.append(built)
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
                for leaf in leaves {
                    switch leaf {
                    case .outbound(let object): outbounds.append(object)
                    case .endpoint(let object): endpoints.append(object)
                    }
                }
                // Pinned lx OutboundManager.Outbound(tag) falls back to EndpointManager.Get(tag),
                // and urltest resolves members through OutboundManager.Outbound; endpoint tags are
                // therefore valid urltest members in v1.14.0-lx.35.
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
                registerReference(location.id, tag: locationTag)

            case .single:
                guard leaves.count == 1 else {
                    throw VPNDirectCoreError.malformedConfig(
                        component: "graph",
                        detail: "Location '\(location.name)' is single but contains \(leaves.count) endpoints"
                    )
                }
                let locationTag = VPNDirectTagFactory.uniqueTag(
                    from: location.id.isEmpty ? location.name : location.id,
                    fallback: leafTags[0],
                    used: &usedTags
                )
                var only = leaves[0].object
                only["tag"] = locationTag
                switch leaves[0] {
                case .outbound: outbounds.append(only)
                case .endpoint: endpoints.append(only)
                }
                locationTags.append(locationTag)
                registerReference(location.endpoints[0].name, tag: locationTag)
                registerReference(location.id, tag: locationTag)
            }
        }

        guard duplicateReferences.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(
                component: "graph",
                detail: "Ambiguous topology reference(s): \(duplicateReferences.sorted().joined(separator: ", "))"
            )
        }

        func resolveDetours(in values: inout [[String: Any]]) throws {
            for index in values.indices {
                guard let reference = values[index].removeValue(forKey: "_vpndirect_detour_ref") as? String else { continue }
                guard let tag = referenceToTag[reference] else {
                    throw VPNDirectCoreError.malformedConfig(component: "graph", detail: "Missing detour target '\(reference)'")
                }
                values[index]["detour"] = tag
            }
        }
        try resolveDetours(in: &outbounds)
        try resolveDetours(in: &endpoints)

        guard !locationTags.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }

        // Pinned selector uses OutboundManager.Outbound(tag); the manager explicitly falls back to
        // EndpointManager.Get(tag), so endpoint-backed single locations are valid selector members.
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

        var config: [String: Any] = [
            "log": ["level": "info", "timestamp": true],
            "dns": [
                "servers": [
                    ["type": "udp", "tag": "dns-remote", "server": "1.1.1.1"],
                    ["type": "local", "tag": "dns-local"],
                ],
                "final": "dns-remote",
                "strategy": "prefer_ipv4",
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.19.0.1/30"],
                "mtu": 9000,
                "auto_route": true,
                "strict_route": true,
                "stack": "gvisor",
            ]],
            "outbounds": [selector, urlTest] + outbounds + [["type": "direct", "tag": "direct"]],
            "route": [
                "auto_detect_interface": true,
                "default_domain_resolver": ["server": "dns-remote", "strategy": "prefer_ipv4"],
                "rules": [
                    ["action": "sniff"],
                    ["protocol": ["dns"], "action": "hijack-dns"],
                    ["ip_is_private": true, "outbound": "direct"],
                ],
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

        // Migrate first, then validate the exact JSON that is returned/launched.
        let migrated = try SingBoxConfigMigrator.migrate(json)
        var error: NSError?
        LibboxCheckConfig(migrated, &error)
        if let error {
            throw VPNDirectCoreError.malformedConfig(component: "libbox-check", detail: error.localizedDescription)
        }

        return GraphResult(
            json: migrated,
            locationCount: locationTags.count,
            leafCount: builtLeafCount,
            firstName: subscription.name
        )
    }

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
        return try build(from: NormalizedSubscription(name: locations.first?.name, locations: locations))
    }
}
