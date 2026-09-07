import Foundation

/// Converts common Xray outbound protocols (VMess / Trojan / Shadowsocks) to sing-box dicts.
/// Unsupported connection semantics fail conversion so `XrayJSONAdapter` can fail closed.
enum XrayLeafConverter {
    private static let supportedNetworks: Set<String> = [
        "ws", "websocket", "grpc", "httpupgrade", "tcp", "raw", "", "http", "h2", "xhttp", "splithttp",
    ]

    static func convert(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let proto = ((xray["protocol"] as? String) ?? "").lowercased()
        switch proto {
        case "vmess": return convertVMess(xray, fallbackTag: fallbackTag)
        case "trojan": return convertTrojan(xray, fallbackTag: fallbackTag)
        case "shadowsocks", "ss": return convertShadowsocks(xray, fallbackTag: fallbackTag)
        default: return nil
        }
    }

    private static func convertVMess(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        guard ensureSupportedNetwork(xray, protocolLabel: "vmess") else { return nil }
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let vnext = ((settings["vnext"] as? [[String: Any]]) ?? []).first
        let address = (vnext?["address"] as? String) ?? ""
        let port = vnext?["port"] as? Int ?? 0
        let user = ((vnext?["users"] as? [[String: Any]]) ?? []).first
        let uuid = (user?["id"] as? String) ?? ""
        guard !address.isEmpty, port > 0, port <= 65535, !uuid.isEmpty,
              !EndpointValidator.isBlockedLoopbackHost(address)
        else { return nil }

        var outbound: [String: Any] = [
            "type": "vmess",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "uuid": uuid,
            "security": (user?["security"] as? String) ?? "auto",
        ]
        if let aid = user?["alterId"] as? Int { outbound["alter_id"] = aid }
        guard applyStreamSecurityAndTransport(xray, to: &outbound) else { return nil }
        return outbound
    }

    private static func convertTrojan(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        guard ensureSupportedNetwork(xray, protocolLabel: "trojan") else { return nil }
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let server = ((settings["servers"] as? [[String: Any]]) ?? []).first
        let address = (server?["address"] as? String) ?? ""
        let port = server?["port"] as? Int ?? 0
        let password = (server?["password"] as? String) ?? ""
        guard !address.isEmpty, port > 0, port <= 65535, !password.isEmpty,
              !EndpointValidator.isBlockedLoopbackHost(address)
        else { return nil }

        var outbound: [String: Any] = [
            "type": "trojan",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "password": password,
        ]
        guard applyStreamSecurityAndTransport(xray, to: &outbound) else { return nil }
        // Trojan requires TLS. If the producer omitted explicit stream TLS, preserve the historical
        // Xray-compatible default to the endpoint name rather than stripping TLS entirely.
        if outbound["tls"] == nil { outbound["tls"] = ["enabled": true, "server_name": address] }
        return outbound
    }

    private static func convertShadowsocks(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let server = ((settings["servers"] as? [[String: Any]]) ?? []).first
        let address = (server?["address"] as? String) ?? ""
        let port = server?["port"] as? Int ?? 0
        let method = (server?["method"] as? String) ?? ""
        let password = (server?["password"] as? String) ?? ""
        guard !address.isEmpty, port > 0, port <= 65535, !method.isEmpty, !password.isEmpty,
              !EndpointValidator.isBlockedLoopbackHost(address)
        else { return nil }
        return [
            "type": "shadowsocks",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "method": method,
            "password": password,
        ]
    }

    private static func applyStreamSecurityAndTransport(_ xray: [String: Any], to outbound: inout [String: Any]) -> Bool {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let security = ((stream["security"] as? String) ?? "none").lowercased()
        guard ["", "none", "tls", "reality"].contains(security) else { return false }
        if security == "tls" || security == "reality" {
            guard let tls = streamTLS(from: xray) else { return false }
            outbound["tls"] = tls
        }
        let network = networkName(from: xray)
        if network != "tcp" && network != "raw" && !network.isEmpty {
            guard let transport = streamTransport(from: xray) else { return false }
            outbound["transport"] = transport
        } else if let transport = streamTransport(from: xray) {
            outbound["transport"] = transport
        }
        return true
    }

    private static func ensureSupportedNetwork(_ xray: [String: Any], protocolLabel: String) -> Bool {
        let network = networkName(from: xray)
        if (network == "xhttp" || network == "splithttp"), !VPNDirectCoreCapabilities.current.supportsXHTTP {
            VPNDirectLog.parser.warning("\(VPNDirectRedactor.redact("xray_leaf_unsupported protocol=\(protocolLabel) network=\(network) (no xhttp capability)"))")
            return false
        }
        guard supportedNetworks.contains(network) else {
            VPNDirectLog.parser.warning("\(VPNDirectRedactor.redact("xray_leaf_unsupported protocol=\(protocolLabel) network=\(network)"))")
            return false
        }
        if network == "tcp" || network == "raw" || network.isEmpty {
            let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
            let tcp = (stream["tcpSettings"] as? [String: Any]) ?? [:]
            let header = (tcp["header"] as? [String: Any]) ?? [:]
            let type = ((header["type"] as? String) ?? "none").lowercased()
            guard type.isEmpty || type == "none" || type == "http" else { return false }
        }
        return true
    }

    private static func networkName(from xray: [String: Any]) -> String {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        return ((stream["network"] as? String) ?? "tcp").lowercased()
    }

    private static func streamTLS(from xray: [String: Any]) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let security = ((stream["security"] as? String) ?? "").lowercased()
        guard security == "tls" || security == "reality" else { return nil }
        let tlsSettings = (stream["tlsSettings"] as? [String: Any]) ?? [:]
        let realitySettings = (stream["realitySettings"] as? [String: Any]) ?? [:]
        let selected = security == "reality" ? realitySettings : tlsSettings

        var tls: [String: Any] = ["enabled": true]
        if let sni = (selected["serverName"] as? String) ?? (tlsSettings["serverName"] as? String), !sni.isEmpty {
            tls["server_name"] = sni
        }
        if let insecure = tlsSettings["allowInsecure"] as? Bool { tls["insecure"] = insecure }
        if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty { tls["alpn"] = alpn }
        if let fingerprint = (selected["fingerprint"] as? String) ?? (tlsSettings["fingerprint"] as? String), !fingerprint.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": fingerprint]
        }
        if security == "reality" {
            guard let publicKey = realitySettings["publicKey"] as? String, !publicKey.isEmpty else { return nil }
            var reality: [String: Any] = ["enabled": true, "public_key": publicKey]
            if let sid = realitySettings["shortId"] as? String, !sid.isEmpty { reality["short_id"] = sid }
            tls["reality"] = reality
        }
        return tls
    }

    private static func streamTransport(from xray: [String: Any]) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let network = networkName(from: xray)
        switch network {
        case "ws", "websocket":
            let ws = (stream["wsSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "ws"]
            if let path = ws["path"] as? String, !path.isEmpty { out["path"] = path }
            if let headers = stringHeaders(ws["headers"]), !headers.isEmpty { out["headers"] = headers }
            if let value = intValue(ws["maxEarlyData"]) { out["max_early_data"] = value }
            if let value = ws["earlyDataHeaderName"] as? String, !value.isEmpty { out["early_data_header_name"] = value }
            return out
        case "grpc":
            let grpc = (stream["grpcSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "grpc"]
            if let service = grpc["serviceName"] as? String, !service.isEmpty { out["service_name"] = service }
            return out
        case "httpupgrade":
            let hu = (stream["httpupgradeSettings"] as? [String: Any]) ?? (stream["httpUpgradeSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "httpupgrade"]
            if let path = hu["path"] as? String, !path.isEmpty { out["path"] = path }
            if let host = hu["host"] as? String, !host.isEmpty { out["host"] = host }
            if let headers = stringHeaders(hu["headers"]), !headers.isEmpty { out["headers"] = headers }
            return out
        case "http", "h2":
            let http = (stream["httpSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "http"]
            if let path = http["path"] as? String, !path.isEmpty { out["path"] = path }
            if let host = http["host"] as? [String], !host.isEmpty { out["host"] = host }
            else if let host = http["host"] as? String, !host.isEmpty { out["host"] = [host] }
            if let method = http["method"] as? String, !method.isEmpty { out["method"] = method }
            if let headers = stringHeaders(http["headers"]), !headers.isEmpty { out["headers"] = headers }
            return out
        case "xhttp", "splithttp":
            let xhttp = (stream["xhttpSettings"] as? [String: Any]) ?? (stream["splithttpSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "xhttp"]
            if let path = xhttp["path"] as? String, !path.isEmpty { out["path"] = path }
            if let host = xhttp["host"] as? String, !host.isEmpty { out["host"] = host }
            else if let headers = stringHeaders(xhttp["headers"]), let host = headers["Host"] ?? headers["host"], !host.isEmpty { out["host"] = host }
            if let mode = xhttp["mode"] as? String, !mode.isEmpty { out["mode"] = mode }
            XrayXHTTPMapper.merge(from: xhttp, into: &out)
            return out
        case "tcp", "raw", "":
            let tcp = (stream["tcpSettings"] as? [String: Any]) ?? [:]
            let header = (tcp["header"] as? [String: Any]) ?? [:]
            let headerType = ((header["type"] as? String) ?? "none").lowercased()
            guard headerType == "http" else { return nil }
            var out: [String: Any] = ["type": "http"]
            let request = (header["request"] as? [String: Any]) ?? [:]
            if let path = request["path"] as? [String], let first = path.first, !first.isEmpty { out["path"] = first }
            if let headers = request["headers"] as? [String: Any] {
                if let host = headers["Host"] as? [String], !host.isEmpty { out["host"] = host }
                else if let host = headers["Host"] as? String, !host.isEmpty { out["host"] = [host] }
            }
            return out
        default:
            return nil
        }
    }

    private static func stringHeaders(_ raw: Any?) -> [String: String]? {
        if let headers = raw as? [String: String] { return headers }
        guard let object = raw as? [String: Any] else { return nil }
        var output: [String: String] = [:]
        for (key, value) in object {
            guard let string = value as? String else { return nil }
            output[key] = string
        }
        return output
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
