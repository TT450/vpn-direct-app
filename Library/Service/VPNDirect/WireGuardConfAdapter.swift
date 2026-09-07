import Foundation

/// Imports WireGuard / AmneziaWG `.conf` into the canonical endpoint model.
/// No first-peer truncation, no guessed default endpoint port, no guessed AWG version.
public enum WireGuardConfAdapter {
    public static func parse(_ text: String, amneziaVersion: String? = nil) throws -> NormalizedSubscription {
        let options = try NormalizedWireGuardEndpoint.parseConf(text, declaredVersion: amneziaVersion)
        guard let dialPeer = options.peers.first(where: { $0.host != nil && $0.port != nil }),
              let host = dialPeer.host,
              let port = dialPeer.port
        else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "No peer has a dialable Endpoint")
        }

        // Keep only non-secret display/fingerprint helpers in string attributes. Runtime emission
        // uses `wireguardEndpoint` exclusively so peers/AWG ranges/reserved bytes are not flattened.
        var attrs: [String: String] = [
            "peer_count": String(options.peers.count),
            "address_count": String(options.address.count),
        ]
        if let mtu = options.mtu { attrs["mtu"] = String(mtu) }
        if let declared = options.declaredAmneziaVersion, !declared.isEmpty {
            attrs["amnezia_version"] = declared
        }

        let isAWG = options.isAmnezia
        let node = NormalizedNode(
            name: isAWG ? "AmneziaWG" : "WireGuard",
            protocolID: isAWG ? .amneziawg : .wireguard,
            server: host,
            port: port,
            attributes: attrs,
            wireguardEndpoint: options
        )
        return NormalizedSubscription(
            name: node.name,
            locations: [
                NormalizedLocation(
                    id: "wg",
                    name: node.name,
                    kind: .group,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }
}
