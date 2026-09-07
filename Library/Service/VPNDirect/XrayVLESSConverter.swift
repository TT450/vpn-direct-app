import Foundation

/// Converts Xray VLESS outbounds to sing-box.
///
/// Supports both the current 3x-ui flat VLESS `settings` shape
/// (`address`/`port`/`id`/`flow`/`encryption`) and the legacy Xray `vnext[]` shape.
/// Explicit connection semantics are never downgraded to plain TCP or unencrypted VLESS.
enum XrayVLESSConverter {
    static func convert(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let network = ((stream["network"] as? String) ?? "tcp").lowercased()
        let supportedNetworks: Set<String> = [
            "tcp", "raw", "", "ws", "websocket", "grpc", "httpupgrade",
            "xhttp", "splithttp", "http", "h2",
        ]
        guard supportedNetworks.contains(network) else {
            // Never turn an explicit unsupported Xray transport (kcp/quic/domainsocket/...)
            // into a working-looking plain TCP outbound.
            return nil
        }
        if (network == "xhttp" || network == "splithttp"), !VPNDirectCoreCapabilities.current.supportsXHTTP {
            return nil
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
            // Current 3x-ui JSON subscription generator shape.
            address = flatAddress
            port = flatPort
            uuid = flatID
            flow = stringValue(settings["flow"]) ?? ""
            encryption = stringValue(settings["encryption"])
        } else {
            // Legacy/native Xray client config shape.
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

        guard !address.isEmpty,
              port > 0, port <= 65535,
              !uuid.isEmpty,
              !EndpointValidator.isBlockedLoopbackHost(address)
        else { return nil }

        var outbound: [String: Any] = [
            "type": "vless",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "uuid": uuid,
        ]
        if !flow.isEmpty {
            outbound["flow"] = flow
        }
        if let encryption, !encryption.isEmpty, encryption.lowercased() != "none" {
            guard VPNDirectCoreCapabilities.current.supportsVLESSEncryption else {
                // A PQ/encryption-bearing source must not silently become ordinary VLESS.
                return nil
            }
            outbound["encryption"] = encryption
        }

        let security = ((stream["security"] as? String) ?? "none").lowercased()
        guard security == "none" || security == "tls" || security == "reality" || security.isEmpty else {
            return nil
        }
        if security == "tls" || security == "reality" {
            let tlsSettings = (stream["tlsSettings"] as? [String: Any]) ?? [:]
            let realitySettings = (stream["realitySettings"] as? [String: Any]) ?? [:]

            let sni = stringValue(realitySettings["serverName"])
                ?? stringValue(tlsSettings["serverName"])
            var tls: [String: Any] = ["enabled": true]
            if let sni, !sni.isEmpty {
                tls["server_name"] = sni
            }

            if let insecure = tlsSettings["allowInsecure"] as? Bool {
                tls["insecure"] = insecure
            }

            let fingerprint = stringValue(realitySettings["fingerprint"])
                ?? stringValue(tlsSettings["fingerprint"])
            if let fingerprint, !fingerprint.isEmpty {
                tls["utls"] = [
                    "enabled": true,
                    "fingerprint": fingerprint,
                ]
            }

            if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty {
                tls["alpn"] = alpn
            } else if let alpn = stringValue(tlsSettings["alpn"]), !alpn.isEmpty {
                tls["alpn"] = alpn.split(separator: ",").map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }
            }

            if security == "reality" {
                guard let pbk = stringValue(realitySettings["publicKey"]), !pbk.isEmpty else {
                    return nil
                }
                var reality: [String: Any] = [
                    "enabled": true,
                    "public_key": pbk,
                ]
                if let sid = stringValue(realitySettings["shortId"]) {
                    let hex = String(sid.filter(\.isHexDigit))
                    if !hex.isEmpty {
                        reality["short_id"] = hex
                    }
                }
                tls["reality"] = reality
            }

            outbound["tls"] = tls
        }

        if network != "tcp" && network != "raw" && !network.isEmpty {
            guard let transport = xrayTransport(network: network, stream: stream) else {
                return nil
            }
            // Reality + explicit stream-one → auto is a pinned lx compatibility quirk retained
            // from the production TheTochka path. Keep this isolated to XHTTP only.
            if security == "reality",
               network == "xhttp" || network == "splithttp",
               ((transport["mode"] as? String) ?? "").lowercased() == "stream-one"
            {
                var fixed = transport
                fixed["mode"] = "auto"
                outbound["transport"] = fixed
            } else {
                outbound["transport"] = transport
            }
        } else if let tcpTransport = xrayTransport(network: network, stream: stream) {
            // TCP with an explicit HTTP header has semantic transport content and must survive.
            outbound["transport"] = tcpTransport
        }

        return outbound
    }

    private static func xrayTransport(network: String, stream: [String: Any]) -> [String: Any]? {
        switch network {
        case "ws", "websocket":
            let ws = (stream["wsSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "ws"]
            if let path = ws["path"] as? String, !path.isEmpty {
                transport["path"] = path
            }
            if let headers = ws["headers"] as? [String: String], !headers.isEmpty {
                transport["headers"] = headers
            } else if let headers = ws["headers"] as? [String: Any], !headers.isEmpty {
                var stringHeaders: [String: String] = [:]
                for (key, value) in headers {
                    guard let value = value as? String else { return nil }
                    stringHeaders[key] = value
                }
                transport["headers"] = stringHeaders
            }
            return transport
        case "grpc":
            let grpc = (stream["grpcSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "grpc"]
            if let service = grpc["serviceName"] as? String, !service.isEmpty {
                transport["service_name"] = service
            }
            return transport
        case "httpupgrade":
            let http = (stream["httpupgradeSettings"] as? [String: Any])
                ?? (stream["httpUpgradeSettings"] as? [String: Any])
                ?? [:]
            var transport: [String: Any] = ["type": "httpupgrade"]
            if let path = http["path"] as? String, !path.isEmpty {
                transport["path"] = path
            }
            if let host = http["host"] as? String, !host.isEmpty {
                transport["host"] = host
            }
            if let headers = http["headers"] as? [String: String], !headers.isEmpty {
                transport["headers"] = headers
            }
            return transport
        case "xhttp", "splithttp":
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
            }
            // Preserve `extra` object keys and merge sibling tuning (scMaxEachPostBytes, …).
            // Do not invent a mode when the producer omitted it; pinned Core owns its default.
            XrayXHTTPExtra.merge(from: xhttp, into: &transport)
            return transport
        case "http", "h2":
            let http = (stream["httpSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "http"]
            if let path = http["path"] as? String, !path.isEmpty {
                transport["path"] = [path]
            } else if let paths = http["path"] as? [String], !paths.isEmpty {
                transport["path"] = paths
            }
            if let host = http["host"] as? [String], !host.isEmpty {
                transport["host"] = host
            } else if let host = http["host"] as? String, !host.isEmpty {
                transport["host"] = [host]
            }
            return transport
        case "tcp", "raw", "":
            let tcp = (stream["tcpSettings"] as? [String: Any]) ?? [:]
            let header = (tcp["header"] as? [String: Any]) ?? [:]
            let headerType = ((header["type"] as? String) ?? "none").lowercased()
            if headerType == "http" {
                var transport: [String: Any] = ["type": "http"]
                let request = (header["request"] as? [String: Any]) ?? [:]
                if let path = request["path"] as? [String], !path.isEmpty {
                    transport["path"] = path
                }
                if let headers = request["headers"] as? [String: Any] {
                    if let host = headers["Host"] as? [String], !host.isEmpty {
                        transport["host"] = host
                    } else if let host = headers["Host"] as? String, !host.isEmpty {
                        transport["host"] = [host]
                    }
                }
                return transport
            }
            // `none` means ordinary TCP and is faithfully represented by no transport object.
            return headerType == "none" || headerType.isEmpty ? nil : nil
        default:
            return nil
        }
    }

    private static func stringValue(_ raw: Any?) -> String? {
        guard let raw else { return nil }
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
