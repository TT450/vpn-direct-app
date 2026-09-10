import Foundation

/// Imports sing-box Tailscale endpoint JSON (`type: tailscale`) into NormalizedSubscription.
public enum TailscaleConfigAdapter {
    public static func parse(_ text: String) throws -> NormalizedSubscription {
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "tailscale", detail: "Invalid JSON")
        }

        var endpoint = json
        if let endpoints = json["endpoints"] as? [[String: Any]],
           let first = endpoints.first(where: { ($0["type"] as? String)?.lowercased() == "tailscale" })
        {
            endpoint = first
        } else if (json["type"] as? String)?.lowercased() != "tailscale" {
            // Allow auth-key only objects from a dedicated Tailscale import form.
            if json["auth_key"] == nil && json["control_url"] == nil {
                throw VPNDirectCoreError.malformedConfig(component: "tailscale", detail: "Missing type=tailscale endpoint")
            }
            endpoint["type"] = "tailscale"
        }
        if endpoint["tag"] == nil {
            endpoint["tag"] = "tailscale"
        }

        let tag = (endpoint["tag"] as? String) ?? "tailscale"
        let control = (endpoint["control_url"] as? String) ?? "https://controlplane.tailscale.com"
        let node = NormalizedNode(
            name: tag,
            protocolID: .tailscale,
            server: URL(string: control)?.host ?? "tailscale",
            port: 443,
            attributes: [
                "control_url": control,
                "has_auth_key": endpoint["auth_key"] != nil ? "1" : "0",
            ],
            outbound: endpoint
        )
        return NormalizedSubscription(
            name: "Tailscale",
            locations: [
                NormalizedLocation(
                    id: "tailscale",
                    name: "Tailscale",
                    kind: .server,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }
}
