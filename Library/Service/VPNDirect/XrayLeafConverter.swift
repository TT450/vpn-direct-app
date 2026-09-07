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
        guard ensureSupportedNetwork(xray, protocolLabel: "trojan") else { return nil }
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

    /// XHTTP / SplitHTTP mapping aligned with the exact pinned sing-box-lx schema.
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
            // Omission and explicit mode are distinct. Pinned Core owns its default.
            transport["mode"] = mode
        }
        XrayXHTTPExtra.merge(from: xhttp, into: &transport)
        return transport
    }
}

/// Maps Xray SplitHTTP/XHTTP tuning into the exact field names/types exposed by
/// Leadaxe/sing-box-lx v1.14.0-lx.35. Unknown `extra` members are deliberately retained under
/// `extra`, which the production builder rejects, so future Xray knobs cannot silently disappear.
enum XrayXHTTPExtra {
    private static let directStringKeys: [(xray: String, sing: String)] = [
        ("xPaddingBytes", "x_padding_bytes"),
        ("scMaxEachPostBytes", "sc_max_each_post_bytes"),
        ("scMinPostsIntervalMs", "sc_min_posts_interval_ms"),
        ("scStreamUpServerSecs", "sc_stream_up_server_secs"),
        ("sessionPlacement", "session_placement"),
        ("sessionKey", "session_key"),
        ("seqPlacement", "seq_placement"),
        ("seqKey", "seq_key"),
        ("sessionTable", "session_table"),
        ("sessionLength", "session_length"),
        ("uplinkDataPlacement", "uplink_data_placement"),
        ("uplinkDataKey", "uplink_data_key"),
        ("uplinkChunkSize", "uplink_chunk_size"),
        ("uplinkHTTPMethod", "uplink_http_method"),
        ("xPaddingKey", "x_padding_key"),
        ("xPaddingHeader", "x_padding_header"),
        ("xPaddingPlacement", "x_padding_placement"),
        ("xPaddingMethod", "x_padding_method"),
    ]

    private static let directIntKeys: [(xray: String, sing: String)] = [
        ("scMaxBufferedPosts", "sc_max_buffered_posts"),
    ]

    private static let directBoolKeys: [(xray: String, sing: String)] = [
        ("noGRPCHeader", "no_grpc_header"),
        ("xPaddingObfsMode", "x_padding_obfs_mode"),
    ]

    private static let xmuxStringKeys: [(xray: String, sing: String)] = [
        ("maxConcurrency", "xmux_max_concurrency"),
        ("hMaxRequestTimes", "xmux_h_max_request_times"),
        ("hMaxReusableSecs", "xmux_h_max_reusable_secs"),
    ]

    private static let xmuxIntKeys: [(xray: String, sing: String)] = [
        ("maxConnections", "xmux_max_connections"),
        ("cMaxReuseTimes", "xmux_c_max_reuse_times"),
        ("hKeepAlivePeriod", "xmux_h_keep_alive_period"),
    ]

    static func merge(from xhttp: [String: Any], into transport: inout [String: Any]) {
        var extra = decodeObject(xhttp["extra"]) ?? [:]

        func sourceValue(_ key: String) -> Any? {
            if let value = xhttp[key] { return value }
            return extra.removeValue(forKey: key)
        }

        for (xrayKey, singKey) in directStringKeys {
            if let raw = sourceValue(xrayKey), let value = rangeString(raw) {
                transport[singKey] = value
            } else if sourceValueWithoutMutation(xray, extra: extra, key: xrayKey) != nil {
                extra[xrayKey] = sourceValueWithoutMutation(xray, extra: extra, key: xrayKey)
            }
        }

        for (xrayKey, singKey) in directIntKeys {
            if let raw = sourceValue(xrayKey), let value = exactInt(raw) {
                transport[singKey] = value
            } else if sourceValueWithoutMutation(xray, extra: extra, key: xrayKey) != nil {
                extra[xrayKey] = sourceValueWithoutMutation(xray, extra: extra, key: xrayKey)
            }
        }

        for (xrayKey, singKey) in directBoolKeys {
            if let raw = sourceValue(xrayKey), let value = exactBool(raw) {
                transport[singKey] = value
            } else if sourceValueWithoutMutation(xray, extra: extra, key: xrayKey) != nil {
                extra[xrayKey] = sourceValueWithoutMutation(xray, extra: extra, key: xrayKey)
            }
        }

        if let download = xhttp["downloadSettings"] ?? extra.removeValue(forKey: "downloadSettings") {
            transport["download_settings"] = download
        }

        let xmuxRaw = xhttp["xmux"] ?? extra.removeValue(forKey: "xmux")
        if let xmux = xmuxRaw as? [String: Any] {
            var unknownXmux = xmux
            for (xrayKey, singKey) in xmuxStringKeys {
                if let raw = unknownXmux.removeValue(forKey: xrayKey) {
                    if let value = rangeString(raw) { transport[singKey] = value }
                    else { unknownXmux[xrayKey] = raw }
                }
            }
            for (xrayKey, singKey) in xmuxIntKeys {
                if let raw = unknownXmux.removeValue(forKey: xrayKey) {
                    if let value = exactInt(raw) { transport[singKey] = value }
                    else { unknownXmux[xrayKey] = raw }
                }
            }
            if let noGRPC = unknownXmux.removeValue(forKey: "noGRPCHeader") {
                if let value = exactBool(noGRPC) { transport["xmux_no_grpc_header"] = value }
                else { unknownXmux["noGRPCHeader"] = noGRPC }
            }
            if !unknownXmux.isEmpty { extra["xmux"] = unknownXmux }
        } else if let xmuxRaw {
            extra["xmux"] = xmuxRaw
        }

        // Xray currently exposes fields that the pinned lx XHTTP option struct does not. They
        // remain in `extra` so the builder fails closed instead of pretending they are supported.
        for unsupported in ["noSSEHeader", "serverMaxHeaderBytes", "scMaxConcurrentPosts"] {
            if let value = xhttp[unsupported] { extra[unsupported] = value }
        }

        if !extra.isEmpty,
           JSONSerialization.isValidJSONObject(extra),
           let data = try? JSONSerialization.data(withJSONObject: extra, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8)
        {
            transport["extra"] = json
        } else if let rawExtra = xhttp["extra"], decodeObject(rawExtra) == nil {
            // Invalid/non-object extra is connection-critical and cannot be normalized safely.
            transport["extra"] = String(describing: rawExtra)
        }
    }

    private static func sourceValueWithoutMutation(_ xhttp: [String: Any], extra: [String: Any], key: String) -> Any? {
        xhttp[key] ?? extra[key]
    }

    private static func decodeObject(_ raw: Any?) -> [String: Any]? {
        if let object = raw as? [String: Any] { return object }
        guard let string = raw as? String, !string.isEmpty,
              let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    /// Pinned lx range fields are JSON strings (`"n"` or `"min-max"`).
    private static func rangeString(_ raw: Any) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber { return value.stringValue }
        if let object = raw as? [String: Any] {
            let from = exactInt(object["from"] ?? object["From"])
            let to = exactInt(object["to"] ?? object["To"])
            if let from, let to { return from == to ? "\(from)" : "\(from)-\(to)" }
        }
        return nil
    }

    private static func exactInt(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let object = raw as? [String: Any],
           let from = exactInt(object["from"] ?? object["From"]),
           let to = exactInt(object["to"] ?? object["To"]),
           from == to
        { return from }
        return nil
    }

    private static func exactBool(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool { return value }
        if let value = raw as? NSNumber { return value.boolValue }
        if let value = raw as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true": return true
            case "0", "false": return false
            default: return nil
            }
        }
        return nil
    }
}
