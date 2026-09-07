import Foundation

/// Imports WireGuard / AmneziaWG `.conf` into NormalizedSubscription.
/// Preserves all peers and AWG fields on `NormalizedNode.wireguardEndpoint`.
public enum WireGuardConfAdapter {
    public static func parse(_ text: String, amneziaVersion: String? = nil) throws -> NormalizedSubscription {
        // Parse with a placeholder version; real version is inferred from fields.
        var options = try AmneziaWGEndpointOptions.parseConf(text, amneziaVersion: amneziaVersion ?? "2")
        let inferred = try AmneziaWGEndpointOptions.inferAmneziaVersion(
            from: options,
            forced: amneziaVersion,
            claimedAWG: amneziaVersion != nil
        )
        if let inferred {
            options.amneziaVersion = inferred
        }

        guard !options.peers.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing peers")
        }
        // Prefer first peer with an endpoint for node.server/port display; keep all peers on options.
        let displayPeer = options.peers.first(where: { ($0.endpoint ?? "").isEmpty == false }) ?? options.peers[0]
        guard let endpoint = displayPeer.endpoint, !endpoint.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing peer endpoint")
        }
        let (host, port) = AmneziaWGEndpointOptions.splitPeerHostPort(endpoint)
        let isAWG = inferred != nil

        var attrs: [String: String] = [
            "private_key": options.privateKey,
            "peer_public_key": displayPeer.publicKey,
            "local_address": options.address.joined(separator: ","),
            "peer_count": String(options.peers.count),
        ]
        if let psk = displayPeer.preSharedKey { attrs["pre_shared_key"] = psk }
        if let mtu = options.mtu { attrs["mtu"] = String(mtu) }
        if isAWG {
            attrs["amnezia_version"] = options.amneziaVersion
        }

        let node = NormalizedNode(
            name: isAWG ? "AmneziaWG" : "WireGuard",
            protocolID: isAWG ? .amneziawg : .wireguard,
            server: host,
            port: Int(port),
            attributes: attrs,
            wireguardEndpoint: options
        )
        return NormalizedSubscription(
            name: isAWG ? "AmneziaWG" : "WireGuard",
            locations: [
                NormalizedLocation(
                    id: "wg",
                    name: isAWG ? "AmneziaWG" : "WireGuard",
                    kind: .server,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }
}
