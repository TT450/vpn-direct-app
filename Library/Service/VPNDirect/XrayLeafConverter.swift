import Foundation

/// Converts common Xray outbound protocols (VMess / Trojan / Shadowsocks) to sing-box dicts.
///
/// Unsupported stream networks (kcp, quic, …) return `nil` so `XrayJSONAdapter` records a convert
/// failure and fail-closes when every leaf in a profile fails.
enum XrayLeafConverter {
    /// Networks we map (or intentionally omit as plain TCP). Anything else is unsupported.
    private static let supportedNetworks: Set<String> = [
        "ws", "websocket", "grpc", "httpupgrade",
        "tcp", "raw", "",
        "http", "h2",
        "xhttp", "splithttp",
    ]

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
        guard ensureSupportedNetwork(xray, protocolLabel: "vmess") else { return nil }
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let address: String
        let port: Int
        let uuid: String
        let security: String
        let alterId: Int?
        if let vnext = ((settings["vnext"] as? [[String: Any]]) ?? []).first {
            address = (vnext["address"] as? String) ?? ""
            port = vnext["port"] as? Int ?? 0
            let user = ((vnext["users"] as? [[String: Any]]) ?? []).first
            uuid = (user?["id"] as? String) ?? ""
            security = (user?["security"] as? String) ?? "auto"
            alterId = user?["alterId"] as? Int
        } else {
            // Flat 3x-ui / panel settings.
            address = (settings["address"] as? String) ?? (settings["server"] as? String) ?? ""
            if let p = settings["port"] as? Int {
                port = p
            } else if let p = settings["port"] as? String, let parsed = Int(p) {
                port = parsed
            } else {
                port = 0
            }
            uuid = (settings["id"] as? String) ?? (settings["uuid"] as? String) ?? ""
            security = (settings["security"] as? String) ?? (settings["scy"] as? String) ?? "auto"
            alterId = settings["alterId"] as? Int ?? settings["aid"] as? Int
        }
        guard !address.isEmpty, port > 0, !uuid.isEmpty else { return nil }
        var outbound: [String: Any] = [
            "type": "vmess",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "uuid": uuid,
            "security": security,
        ]
        if let aid = alterId { outbound["alter_id"] = aid }
        if let tls = streamTLS(from: xray) { outbound["tls"] = tls }
        if let transport = streamTransport(from: xray) { outbound["transport"] = transport }
        switch XrayMuxAndMask.apply(from: xray, into: &outbound) {
        case .ok: return outbound
        case .unsupported: return nil
        }
    }

    private static func convertTrojan(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        guard ensureSupportedNetwork(xray, protocolLabel: "trojan") else { return nil }
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let address: String
        let port: Int
        let password: String
        if let servers = ((settings["servers"] as? [[String: Any]]) ?? []).first {
            address = (servers["address"] as? String) ?? ""
            port = servers["port"] as? Int ?? 0
            password = (servers["password"] as? String) ?? ""
        } else {
            address = (settings["address"] as? String) ?? (settings["server"] as? String) ?? ""
            if let p = settings["port"] as? Int {
                port = p
            } else if let p = settings["port"] as? String, let parsed = Int(p) {
                port = parsed
            } else {
                port = 0
            }
            password = (settings["password"] as? String) ?? ""
        }
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
        switch XrayMuxAndMask.apply(from: xray, into: &outbound) {
        case .ok: return outbound
        case .unsupported: return nil
        }
    }

    private static func convertShadowsocks(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let address: String
        let port: Int
        let method: String
        let password: String
        if let servers = ((settings["servers"] as? [[String: Any]]) ?? []).first {
            address = (servers["address"] as? String) ?? ""
            port = servers["port"] as? Int ?? 0
            method = (servers["method"] as? String) ?? ""
            password = (servers["password"] as? String) ?? ""
        } else {
            address = (settings["address"] as? String) ?? (settings["server"] as? String) ?? ""
            if let p = settings["port"] as? Int {
                port = p
            } else if let p = settings["port"] as? String, let parsed = Int(p) {
                port = parsed
            } else {
                port = 0
            }
            method = (settings["method"] as? String) ?? ""
            password = (settings["password"] as? String) ?? ""
        }
        guard !address.isEmpty, port > 0, !method.isEmpty, !password.isEmpty else { return nil }
        var outbound: [String: Any] = [
            "type": "shadowsocks",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "method": method,
            "password": password,
        ]
        switch XrayMuxAndMask.apply(from: xray, into: &outbound) {
        case .ok: return outbound
        case .unsupported: return nil
        }
    }

    private static func ensureSupportedNetwork(_ xray: [String: Any], protocolLabel: String) -> Bool {
        let network = networkName(from: xray)
        if (network == "xhttp" || network == "splithttp"), !VPNDirectCoreCapabilities.current.supportsXHTTP {
            VPNDirectLog.parser.warning(
                "\(VPNDirectRedactor.redact("xray_leaf_unsupported protocol=\(protocolLabel) network=\(network) (no xhttp capability)"))"
            )
            return false
        }
        guard supportedNetworks.contains(network) else {
            VPNDirectLog.parser.warning(
                "\(VPNDirectRedactor.redact("xray_leaf_unsupported protocol=\(protocolLabel) network=\(network)"))"
            )
            return false
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
        let tlsSettings = (stream["tlsSettings"] as? [String: Any])
            ?? (stream["realitySettings"] as? [String: Any])
            ?? [:]
        var tls: [String: Any] = ["enabled": true]
        if let sni = tlsSettings["serverName"] as? String { tls["server_name"] = sni }
        if let alpn = tlsSettings["alpn"] as? [String] { tls["alpn"] = alpn }
        if let fingerprint = tlsSettings["fingerprint"] as? String, !fingerprint.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": fingerprint]
        }
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
        case "ws", "websocket":
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
            let hu = (stream["httpupgradeSettings"] as? [String: Any])
                ?? (stream["httpUpgradeSettings"] as? [String: Any])
                ?? [:]
            var out: [String: Any] = ["type": "httpupgrade"]
            if let path = hu["path"] as? String { out["path"] = path }
            if let host = hu["host"] as? String { out["host"] = host }
            return out
        case "http", "h2":
            let http = (stream["httpSettings"] as? [String: Any]) ?? [:]
            var out: [String: Any] = ["type": "http"]
            if let path = http["path"] as? String, !path.isEmpty {
                out["path"] = [path]
            } else if let paths = http["path"] as? [String], !paths.isEmpty {
                out["path"] = paths
            }
            if let host = http["host"] as? [String], !host.isEmpty {
                out["host"] = host
            } else if let host = http["host"] as? String, !host.isEmpty {
                out["host"] = [host]
            }
            return out
        case "xhttp", "splithttp":
            return xhttpTransport(from: stream)
        case "tcp", "raw", "":
            let tcp = (stream["tcpSettings"] as? [String: Any]) ?? [:]
            let header = (tcp["header"] as? [String: Any]) ?? [:]
            if ((header["type"] as? String) ?? "none").lowercased() == "http" {
                var out: [String: Any] = ["type": "http"]
                let request = (header["request"] as? [String: Any]) ?? [:]
                if let path = request["path"] as? [String], !path.isEmpty {
                    out["path"] = path
                }
                if let headers = request["headers"] as? [String: Any] {
                    if let host = headers["Host"] as? [String], !host.isEmpty {
                        out["host"] = host
                    } else if let host = headers["Host"] as? String, !host.isEmpty {
                        out["host"] = [host]
                    }
                }
                return out
            }
            return nil
        default:
            return nil
        }
    }

    /// XHTTP / SplitHTTP mapping aligned with `XrayVLESSConverter`.
    private static func xhttpTransport(from stream: [String: Any]) -> [String: Any] {
        let xhttp = (stream["xhttpSettings"] as? [String: Any])
            ?? (stream["splithttpSettings"] as? [String: Any])
            ?? [:]
        var transport: [String: Any] = ["type": "xhttp"]
        if let path = xhttp["path"] as? String, !path.isEmpty {
            transport["path"] = path
        }
        if let host = xhttp["host"] as? String, !host.isEmpty {
            transport["host"] = host
        } else if let headers = xhttp["headers"] as? [String: String],
                  let host = headers["Host"] ?? headers["host"], !host.isEmpty
        {
            transport["host"] = host
        }
        if let mode = xhttp["mode"] as? String, !mode.isEmpty {
            transport["mode"] = mode
        } else {
            transport["mode"] = "auto"
        }
        XrayXHTTPExtra.merge(from: xhttp, into: &transport)
        return transport
    }
}

/// Shared XHTTP `extra` + sibling tuning keys (scMaxEachPostBytes, …).
enum XrayXHTTPExtra {
    private static let siblingKeys: [(xray: String, sing: String)] = [
        ("scMaxEachPostBytes", "sc_max_each_post_bytes"),
        ("scMinPostsIntervalMs", "sc_min_posts_interval_ms"),
        ("scMaxConcurrentPosts", "sc_max_concurrent_posts"),
        ("xPaddingBytes", "x_padding_bytes"),
        ("noGRPCHeader", "no_grpc_header"),
        ("xmux", "xmux"),
    ]

    static func merge(from xhttp: [String: Any], into transport: inout [String: Any]) {
        var extraMerged: [String: Any] = [:]
        if let extraObj = xhttp["extra"] as? [String: Any] {
            extraMerged = extraObj
        } else if let extraStr = xhttp["extra"] as? String, !extraStr.isEmpty,
                  let data = extraStr.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            extraMerged = obj
        } else if let extraStr = xhttp["extra"] as? String, !extraStr.isEmpty {
            transport["extra"] = extraStr
        }

        for (xrayKey, singKey) in siblingKeys {
            guard let raw = xhttp[xrayKey] else { continue }
            if transport[singKey] == nil {
                transport[singKey] = stringifyScalar(raw) ?? raw
            }
            if extraMerged[xrayKey] == nil {
                extraMerged[xrayKey] = raw
            }
        }

        if !extraMerged.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: extraMerged),
           let extraJSON = String(data: data, encoding: .utf8)
        {
            transport["extra"] = extraJSON
        }
    }

    private static func stringifyScalar(_ raw: Any) -> Any? {
        if raw is String || raw is NSNumber || raw is Bool { return raw }
        if let arr = raw as? [Any] {
            return arr.map { "\($0)" }.joined(separator: ",")
        }
        return nil
    }
}
