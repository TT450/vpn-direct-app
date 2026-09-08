import Foundation

/// Imports MASQUE CONNECT-UDP (RFC 9298) outbound JSON into NormalizedSubscription.
public enum MasqueConnectUDPAdapter {
    public static func parse(_ text: String) throws -> NormalizedSubscription {
        guard VPNDirectCoreCapabilities.current.supportsMASQUEConnectUDP else {
            throw VPNDirectCoreError.unsupportedFeature(
                component: "masque.connect_udp",
                detail: "CONNECT-UDP not available in this Libbox build"
            )
        }
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "masque-connect-udp", detail: "Invalid JSON")
        }

        var outbound = json
        if let outs = json["outbounds"] as? [[String: Any]],
           let first = outs.first(where: { isConnectUDP($0) })
        {
            outbound = first
        } else if !isConnectUDP(json) {
            throw VPNDirectCoreError.malformedConfig(
                component: "masque-connect-udp",
                detail: "Expected type masque-connect-udp (or masque + mode=connect-udp)"
            )
        }

        outbound["type"] = "masque-connect-udp"
        if outbound["tag"] == nil { outbound["tag"] = "masque-connect-udp" }

        let server = (outbound["server"] as? String) ?? ""
        let port = (outbound["server_port"] as? Int)
            ?? (outbound["server_port"] as? NSNumber)?.intValue
            ?? 443
        guard !server.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "masque-connect-udp", detail: "Missing server")
        }

        let node = NormalizedNode(
            name: (outbound["tag"] as? String) ?? "MASQUE CONNECT-UDP",
            protocolID: .masqueConnectUDP,
            server: server,
            port: port,
            attributes: [
                "uri": (outbound["uri"] as? String) ?? "",
                "vhttp": (outbound["vhttp"] as? String) ?? "h3",
            ],
            outbound: outbound
        )
        return NormalizedSubscription(
            name: "MASQUE CONNECT-UDP",
            locations: [
                NormalizedLocation(
                    id: "masque-connect-udp",
                    name: "MASQUE CONNECT-UDP",
                    kind: .server,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }

    private static func isConnectUDP(_ obj: [String: Any]) -> Bool {
        let type = (obj["type"] as? String)?.lowercased() ?? ""
        if type == "masque-connect-udp" { return true }
        if type == "masque" {
            let mode = (obj["mode"] as? String)?.lowercased() ?? ""
            let proto = (obj["protocol"] as? String)?.lowercased() ?? ""
            return mode == "connect-udp" || proto == "connect-udp"
        }
        return false
    }
}
