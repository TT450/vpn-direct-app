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
        if EndpointValidator.isBlockedLoopbackHost(server) || EndpointValidator.isPanelStubLink(link) {
            throw VPNDirectCoreError.unsupportedFeature(component: "vless", detail: "Loopback/panel stub rejected")
        }
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
        let encryption = outbound["encryption"] as? String
        if VLESSPlaintextGuard.isInsecurePublicVLESS(
            server: server,
            hasTLSOrReality: tlsEnabled || reality,
            encryption: encryption
        ) {
            throw VPNDirectCoreError.plaintextVLESS(tag: parsed.name)
        }

        var attributes: [String: String] = [:]
        var rawExtensions: [String: String] = [:]
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
            attributes["type"] = transportType
            if let path = transport["path"] as? String { attributes["path"] = path }
            if let service = transport["service_name"] as? String { attributes["service_name"] = service }
            if let mode = transport["mode"] as? String { attributes["mode"] = mode }
            if let extra = transport["extra"] as? String {
                attributes["extra"] = extra
                rawExtensions["xhttp.extra"] = extra
            }
            if let headers = transport["headers"] as? [String: String], let host = headers["Host"] {
                attributes["host"] = host
            }
        }
        // Preserve full query map for diagnostics / future builders.
        for (k, v) in ShareLinkURI.queryMap(from: link) {
            if attributes[k] == nil {
                switch CompatibilityFieldPolicy.classify(key: k, value: v) {
                case .harmlessMetadata, .panelMetadata, .futureField:
                    rawExtensions[k] = v
                case .protocolExtension, .connectionCritical:
                    attributes[k] = v
                }
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
            rawExtensions: rawExtensions,
            source: link
        )
    }
}
