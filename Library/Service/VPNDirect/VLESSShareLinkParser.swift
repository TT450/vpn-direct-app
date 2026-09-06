import Foundation

/// Adapts existing `VLESSConfigBuilder` into the NormalizedNode pipeline.
public struct VLESSShareLinkParser: VPNDirectParser {
    public init() {}

    public var supportedSchemes: [String] { ["vless"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let parsed = try VLESSConfigBuilder.parseOutbound(link, tag: "proxy")
        let outbound = parsed.outbound
        let server = outbound["server"] as? String ?? ""
        let port = outbound["server_port"] as? Int ?? 0
        let transportType = ((outbound["transport"] as? [String: Any])?["type"] as? String)
            ?? "tcp"
        let tlsEnabled = ((outbound["tls"] as? [String: Any])?["enabled"] as? Bool) ?? false
        let reality = ((outbound["tls"] as? [String: Any])?["reality"] as? [String: Any]) != nil
        let security: VPNDirectSecurityID
        if reality {
            security = .reality
        } else if tlsEnabled {
            security = .tls
        } else {
            security = .none
        }

        var attributes: [String: String] = [:]
        if let encryption = outbound["encryption"] as? String {
            attributes["encryption"] = encryption
        }
        if let flow = outbound["flow"] as? String {
            attributes["flow"] = flow
        }

        return NormalizedNode(
            name: parsed.name,
            protocolID: .vless,
            server: server,
            port: port,
            transport: VPNDirectTransportID(rawValue: transportType),
            security: security,
            uuid: parsed.uuid,
            attributes: attributes,
            source: link,
            outbound: outbound
        )
    }
}
