import Foundation

/// Converts Xray VLESS outbounds to sing-box without semantic downgrades.
/// Supports current flat 3x-ui settings and legacy Xray vnext[].
enum XrayVLESSConverter {
    static func convert(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let network = ((stream["network"] as? String) ?? "tcp").lowercased()
        let supportedNetworks: Set<String> = [
            "tcp", "raw", "", "ws", "websocket", "grpc", "httpupgrade",
            "xhttp", "splithttp", "http", "h2",
        ]
        guard supportedNetworks.contains(network) else { return nil }
        if (network == "xhttp" || network == "splithttp"), !VPNDirectCoreCapabilities.current.supportsXHTTP {
            return nil
        }

        if network == "tcp" || network == "raw" || network.isEmpty {
            let tcp = (stream["tcpSettings"] as? [String: Any]) ?? [:]
            let header = (tcp["header"] as? [String: Any]) ?? [:]
            let headerType = ((header["type"] as? String) ?? "none")
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard headerType.isEmpty || headerType == "none" || headerType == "http" else { return nil }
        }

        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let address: String
        let port: Int
        let uuid: String
        let flow: String
        let encryption: String?

        if let flatAddress = stringValue(settings["address"]),
           let flatPort = intValue(settings["port"]),
           let flatID = stringValue(settings["id"])
        {
            address = flatAddress
            port = flatPort
            uuid = flatID
            flow = stringValue(settings["flow"]) ?? ""
            encryption = stringValue(settings["encryption"])
        } else {
            guard let vnext = (settings["vnext"] as? [[String: Any]])?.first,
                  let nestedAddress = stringValue(vnext["address"]),
                  let nestedPort = intValue(vnext["port"]),
                  let user = (vnext["users"] as? [[String: Any]])?.first,
                  let nestedID = stringValue(user["id"])
            else { return nil }
            address = nestedAddress
            port = nestedPort
            uuid = nestedID
            flow = stringValue(user["flow"]) ?? ""
            encryption = stringValue(user["encryption"])
        }

        guard !address.isEmpty, (1...65535).contains(port), !uuid.isEmpty,
              !EndpointValidator.isBlockedLoopbackHost(address) else { return nil }

        var outbound: [String: Any] = [
            "type": "vless",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "uuid": uuid,
        ]
        if !flow.isEmpty { outbound["flow"] = flow }
        if let encryption, !encryption.isEmpty, encryption.lowercased() != "none" {
            guard VPNDirectCoreCapabilities.current.supportsVLESSEncryption else { return nil }
            outbound["encryption"] = encryption
        }
        if let packet = stringValue(settings["packet_encoding"] ?? settings["packetEncoding"]) {
            outbound["packet_encoding"] = packet
        }

        let security = ((stream["security"] as? String) ?? "none").lowercased()
        guard security == "none" || security == "tls" || security == "reality" || security.isEmpty else { return nil }
        if security == "tls" || security == "reality" {
            let tlsSettings = (stream["tlsSettings"] as? [String: Any]) ?? [:]
            let realitySettings = (stream["realitySettings"] as? [String: Any]) ?? [:]
            var tls: [String: Any] = ["enabled": true]
            if let sni = stringValue(realitySettings["serverName"]) ?? stringValue(tlsSettings["serverName"]), !sni.isEmpty {
                tls["server_name"] = sni
            }
            if let insecure = tlsSettings["allowInsecure"] as? Bool { tls["insecure"] = insecure }
            let fingerprint = stringValue(realitySettings["fingerprint"]) ?? stringValue(tlsSettings["fingerprint"])
            if let fingerprint, !fingerprint.isEmpty {
                tls["utls"] = ["enabled": true, "fingerprint": fingerprint]
            }
            if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty {
                tls["alpn"] = alpn
            } else if let alpn = stringValue(tlsSettings["alpn"]), !alpn.isEmpty {
                tls["alpn"] = alpn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            if security == "reality" {
                guard let pbk = stringValue(realitySettings["publicKey"]), !pbk.isEmpty else { return nil }
                var reality: [String: Any] = ["enabled": true, "public_key": pbk]
                if let sid = stringValue(realitySettings["shortId"]) {
                    let hex = String(sid.filter(\.isHexDigit))
                    if !hex.isEmpty { reality["short_id"] = hex }
                }
                tls["reality"] = reality
            }
            outbound["tls"] = tls
        }

        if network != "tcp" && network != "raw" && !network.isEmpty {
            guard let transport = xrayTransport(network: network, stream: stream) else { return nil }
            outbound["transport"] = transport
        } else if let transport = xrayTransport(network: network, stream: stream) {
            outbound["transport"] = transport
        }

        switch XrayMuxAndMask.apply(from: xray, into: &outbound) {
        case .ok: return outbound
        case .unsupported: return nil
        }
    }

    private static func xrayTransport(network: String, stream: [String: Any]) -> [String: Any]? {
        switch network {
        case "ws", "websocket":
            let ws = (stream["wsSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "ws"]
            if let path = ws["path"] as? String, !path.isEmpty { transport["path"] = path }
            if let headers = ws["headers"] as? [String: String], !headers.isEmpty {
                transport["headers"] = headers
            } else if let headers = ws["headers"] as? [String: Any], !headers.isEmpty {
                var out: [String: String] = [:]
                for (key, value) in headers {
                    guard let value = value as? String else { return nil }
                    out[key] = value
                }
                transport["headers"] = out
            }
            if let early = intValue(ws["maxEarlyData"] ?? ws["max_early_data"]), early >= 0 { transport["max_early_data"] = early }
            if let header = stringValue(ws["earlyDataHeaderName"] ?? ws["early_data_header_name"]) { transport["early_data_header_name"] = header }
            return transport

        case "grpc":
            let grpc = (stream["grpcSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "grpc"]
            if let service = stringValue(grpc["serviceName"] ?? grpc["service_name"]) { transport["service_name"] = service }
            if let idle = stringValue(grpc["idle_timeout"] ?? grpc["idleTimeout"]) { transport["idle_timeout"] = idle }
            if let ping = stringValue(grpc["ping_timeout"] ?? grpc["pingTimeout"]) { transport["ping_timeout"] = ping }
            if let permit = boolValue(grpc["permit_without_stream"] ?? grpc["permitWithoutStream"]) { transport["permit_without_stream"] = permit }
            return transport

        case "httpupgrade":
            let http = (stream["httpupgradeSettings"] as? [String: Any])
                ?? (stream["httpUpgradeSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "httpupgrade"]
            if let path = stringValue(http["path"]) { transport["path"] = path }
            if let host = stringValue(http["host"]) { transport["host"] = host }
            if let headers = http["headers"] as? [String: String], !headers.isEmpty { transport["headers"] = headers }
            return transport

        case "xhttp", "splithttp":
            let xhttp = (stream["xhttpSettings"] as? [String: Any])
                ?? (stream["splithttpSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "xhttp"]
            if let path = stringValue(xhttp["path"]) { transport["path"] = path }
            if let host = stringValue(xhttp["host"]) {
                transport["host"] = host
            } else if let headers = xhttp["headers"] as? [String: String], let host = headers["Host"] ?? headers["host"], !host.isEmpty {
                transport["host"] = host
            }
            if let mode = stringValue(xhttp["mode"]) { transport["mode"] = mode }
            XrayXHTTPMapper.merge(from: xhttp, into: &transport)
            return transport

        case "http", "h2":
            let http = (stream["httpSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "http"]
            if let paths = http["path"] as? [String], !paths.isEmpty { transport["path"] = paths }
            else if let path = stringValue(http["path"]) { transport["path"] = [path] }
            if let hosts = http["host"] as? [String], !hosts.isEmpty { transport["host"] = hosts }
            else if let host = stringValue(http["host"]) { transport["host"] = [host] }
            if let method = stringValue(http["method"]) { transport["method"] = method }
            if let headers = http["headers"] as? [String: String], !headers.isEmpty { transport["headers"] = headers }
            if let idle = stringValue(http["idle_timeout"] ?? http["idleTimeout"]) { transport["idle_timeout"] = idle }
            if let ping = stringValue(http["ping_timeout"] ?? http["pingTimeout"]) { transport["ping_timeout"] = ping }
            return transport

        case "tcp", "raw", "":
            let tcp = (stream["tcpSettings"] as? [String: Any]) ?? [:]
            let header = (tcp["header"] as? [String: Any]) ?? [:]
            let headerType = ((header["type"] as? String) ?? "none").lowercased()
            if headerType == "http" {
                var transport: [String: Any] = ["type": "http"]
                let request = (header["request"] as? [String: Any]) ?? [:]
                if let paths = request["path"] as? [String], !paths.isEmpty { transport["path"] = paths }
                if let headers = request["headers"] as? [String: Any] {
                    if let hosts = headers["Host"] as? [String], !hosts.isEmpty { transport["host"] = hosts }
                    else if let host = headers["Host"] as? String, !host.isEmpty { transport["host"] = [host] }
                }
                return transport
            }
            return nil
        default:
            return nil
        }
    }

    private static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
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
