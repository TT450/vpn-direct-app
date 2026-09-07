import Foundation

/// Imports WireGuard / AmneziaWG `.conf` into NormalizedSubscription.
public enum WireGuardConfAdapter {
    public static func parse(_ text: String, amneziaVersion: String? = nil) throws -> NormalizedSubscription {
        let version = amneziaVersion ?? (text.lowercased().contains("jc") || text.lowercased().contains("h1") ? "2" : "2")
        let options = try AmneziaWGEndpointOptions.parseConf(text, amneziaVersion: version)
        guard let peer = options.peers.first, let endpoint = peer.endpoint, !endpoint.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing peer endpoint")
        }
        let (host, port) = splitEndpoint(endpoint)
        var attrs: [String: String] = [
            "private_key": options.privateKey,
            "peer_public_key": peer.publicKey,
            "local_address": options.address.joined(separator: ","),
        ]
        if let psk = peer.preSharedKey { attrs["pre_shared_key"] = psk }
        if let mtu = options.mtu { attrs["mtu"] = String(mtu) }
        let isAWG = options.jc != nil || options.h1 != nil || options.headerProtectionKey != nil
            || version.hasPrefix("3") || text.lowercased().contains("jc")
        if isAWG {
            attrs["amnezia_version"] = options.amneziaVersion
            if let jc = options.jc { attrs["jc"] = String(jc) }
            if let jmin = options.jmin { attrs["jmin"] = String(jmin) }
            if let jmax = options.jmax { attrs["jmax"] = String(jmax) }
            if let s1 = options.s1 { attrs["s1"] = String(s1) }
            if let s2 = options.s2 { attrs["s2"] = String(s2) }
            if let h1 = options.h1 { attrs["h1"] = h1 }
            if let h2 = options.h2 { attrs["h2"] = h2 }
            if let h3 = options.h3 { attrs["h3"] = h3 }
            if let h4 = options.h4 { attrs["h4"] = h4 }
        }
        let node = NormalizedNode(
            name: "WireGuard",
            protocolID: isAWG ? .amneziawg : .wireguard,
            server: host,
            port: port,
            attributes: attrs
        )
        return NormalizedSubscription(
            name: "WireGuard",
            locations: [
                NormalizedLocation(id: "wg", name: "WireGuard", kind: .country, strategy: .single, endpoints: [node]),
            ]
        )
    }

    private static func splitEndpoint(_ endpoint: String) -> (String, Int) {
        if endpoint.hasPrefix("["), let close = endpoint.firstIndex(of: "]") {
            let host = String(endpoint[endpoint.index(after: endpoint.startIndex)..<close])
            let rest = endpoint[endpoint.index(after: close)...]
            let port = Int(rest.dropFirst()) ?? 51820
            return (host, port)
        }
        if let idx = endpoint.lastIndex(of: ":") {
            let host = String(endpoint[..<idx])
            let port = Int(endpoint[endpoint.index(after: idx)...]) ?? 51820
            return (host, port)
        }
        return (endpoint, 51820)
    }
}
