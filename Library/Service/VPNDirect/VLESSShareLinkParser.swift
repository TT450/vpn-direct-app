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
        if let tls = outbound["tls"] as? [String: Any] {
            if let sni = tls["server_name"] as? String { attributes["sni"] = sni }
            if let reality = tls["reality"] as? [String: Any] {
                if let pbk = reality["public_key"] as? String { attributes["pbk"] = pbk }
                if let sid = reality["short_id"] as? String { attributes["sid"] = sid }
            }
            if let utls = tls["utls"] as? [String: Any], let fp = utls["fingerprint"] as? String {
                attributes["fp"] = fp
            }
        }
        if let transport = outbound["transport"] as? [String: Any] {
            if let path = transport["path"] as? String { attributes["path"] = path }
            if let service = transport["service_name"] as? String { attributes["service_name"] = service }
            if let headers = transport["headers"] as? [String: String], let host = headers["Host"] {
                attributes["host"] = host
            }
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
            source: link
            // attributes-only — UniversalOutboundBuilder rebuilds outbound
        )
    }
}
