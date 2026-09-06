import Foundation

/// Converts common Xray outbound protocols (VMess / Trojan / Shadowsocks) to sing-box dicts.
enum XrayLeafConverter {
    static func convert(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let proto = ((xray["protocol"] as? String) ?? "").lowercased()
        switch proto {
        case "vmess":
            return convertVMess(xray, fallbackTag: fallbackTag)
        case "trojan":
            return convertTrojan(xray, fallbackTag: fallbackTag)
        case "shadowsocks", "ss":
            return convertShadowsocks(xray, fallbackTag: fallbackTag)
        default:
            return nil
        }
    }

    private static func convertVMess(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let vnext = ((settings["vnext"] as? [[String: Any]]) ?? []).first
        let address = (vnext?["address"] as? String) ?? ""
        let port = vnext?["port"] as? Int ?? 0
        let user = ((vnext?["users"] as? [[String: Any]]) ?? []).first
        let uuid = (user?["id"] as? String) ?? ""
        guard !address.isEmpty, port > 0, !uuid.isEmpty else { return nil }
        var outbound: [String: Any] = [
            "type": "vmess",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "uuid": uuid,
            "security": (user?["security"] as? String) ?? "auto",
        ]
        if let aid = user?["alterId"] as? Int { outbound["alter_id"] = aid }
        if let tls = streamTLS(from: xray) { outbound["tls"] = tls }
        if let transport = streamTransport(from: xray) { outbound["transport"] = transport }
        return outbound
    }

    private static func convertTrojan(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let servers = ((settings["servers"] as? [[String: Any]]) ?? []).first
        let address = (servers?["address"] as? String) ?? ""
        let port = servers?["port"] as? Int ?? 0
        let password = (servers?["password"] as? String) ?? ""
        guard !address.isEmpty, port > 0, !password.isEmpty else { return nil }
        var outbound: [String: Any] = [
            "type": "trojan",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "password": password,
        ]
        if let tls = streamTLS(from: xray) {
            outbound["tls"] = tls
        } else {
            outbound["tls"] = ["enabled": true, "server_name": address]
        }
        if let transport = streamTransport(from: xray) { outbound["transport"] = transport }
        return outbound
    }

    private static func convertShadowsocks(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let servers = ((settings["servers"] as? [[String: Any]]) ?? []).first
        let address = (servers?["address"] as? String) ?? ""
        let port = servers?["port"] as? Int ?? 0
        let method = (servers?["method"] as? String) ?? ""
        let password = (servers?["password"] as? String) ?? ""
        guard !address.isEmpty, port > 0, !method.isEmpty, !password.isEmpty else { return nil }
        return [
            "type": "shadowsocks",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "method": method,
            "password": password,
        ]
    }

    private static func streamTLS(from xray: [String: Any]) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let security = ((stream["security"] as? String) ?? "").lowercased()
        guard security == "tls" || security == "reality" else { return nil }
        let tlsSettings = (stream["tlsSettings"] as? [String: Any])
            ?? (stream["realitySettings"] as? [String: Any])
            ?? [:]
        var tls: [String: Any] = ["enabled": true]
        if let sni = tlsSettings["serverName"] as? String { tls["server_name"] = sni }
        if let alpn = tlsSettings["alpn"] as? [String] { tls["alpn"] = alpn }
        if security == "reality" {
            var reality: [String: Any] = ["enabled": true]
            if let pbk = tlsSettings["publicKey"] as? String { reality["public_key"] = pbk }
            if let sid = tlsSettings["shortId"] as? String { reality["short_id"] = sid }
            tls["reality"] = reality
        }
        return tls
    }

    private static func streamTransport(from xray: [String: Any]) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let network = ((stream["network"] as? String) ?? "tcp").lowercased()
        switch network {
        case "ws":
            let ws = (stream["wsSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "ws"]
            if let path = ws["path"] as? String { out["path"] = path }
            if let headers = ws["headers"] as? [String: String] { out["headers"] = headers }
            return out
        case "grpc":
            let grpc = (stream["grpcSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "grpc"]
            if let service = grpc["serviceName"] as? String { out["service_name"] = service }
            return out
        case "httpupgrade":
            let hu = (stream["httpupgradeSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "httpupgrade"]
            if let path = hu["path"] as? String { out["path"] = path }
            if let host = hu["host"] as? String { out["host"] = host }
            return out
        default:
            return nil
        }
    }
}
