import Foundation

/// Converts Xray VLESS outbounds to sing-box (fail-closed XHTTP).
enum XrayVLESSConverter {
    static func convert(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let network = ((stream["network"] as? String) ?? "tcp").lowercased()
        if (network == "xhttp" || network == "splithttp"), !VPNDirectCoreCapabilities.current.supportsXHTTP {
            return nil
        }

        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        // Nested Xray vnext[] OR flat 3x-ui / panel settings (address/port/id).
        let address: String
        let port: Int
        let uuid: String
        let flow: String
        let encryptionRaw: String?
        if let vnext = (settings["vnext"] as? [[String: Any]])?.first {
            address = (vnext["address"] as? String) ?? ""
            port = vnext["port"] as? Int ?? 443
            let user = (vnext["users"] as? [[String: Any]])?.first ?? [:]
            uuid = (user["id"] as? String) ?? ""
            flow = ((user["flow"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            encryptionRaw = user["encryption"] as? String
        } else {
            address = (settings["address"] as? String)
                ?? (settings["server"] as? String)
                ?? ""
            if let p = settings["port"] as? Int {
                port = p
            } else if let p = settings["port"] as? String, let parsed = Int(p) {
                port = parsed
            } else {
                port = 443
            }
            uuid = (settings["id"] as? String)
                ?? (settings["uuid"] as? String)
                ?? ""
            flow = ((settings["flow"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            encryptionRaw = settings["encryption"] as? String
        }
        guard !address.isEmpty, !EndpointValidator.isBlockedLoopbackHost(address) else { return nil }
        guard !uuid.isEmpty else { return nil }

        var outbound: [String: Any] = [
            "type": "vless",
            "tag": (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag,
            "server": address,
            "server_port": port,
            "uuid": uuid,
            "packet_encoding": "xudp",
        ]
        if !flow.isEmpty {
            outbound["flow"] = flow
        }
        if let encryption = encryptionRaw,
           !encryption.isEmpty,
           encryption.lowercased() != "none"
        {
            guard VPNDirectCoreCapabilities.current.supportsVLESSEncryption else {
                // Fail closed — never silently strip connection-critical encryption/PQ.
                return nil
            }
            outbound["encryption"] = encryption
        }

        let security = ((stream["security"] as? String) ?? "none").lowercased()
        if security == "tls" || security == "reality" {
            let tlsSettings = (stream["tlsSettings"] as? [String: Any]) ?? [:]
            let realitySettings = (stream["realitySettings"] as? [String: Any]) ?? [:]

            let sni = (realitySettings["serverName"] as? String)
                ?? (tlsSettings["serverName"] as? String)
                ?? address
            var tls: [String: Any] = [
                "enabled": true,
                "server_name": sni,
            ]

            if let insecure = tlsSettings["allowInsecure"] as? Bool {
                tls["insecure"] = insecure
            }

            let fingerprint = (realitySettings["fingerprint"] as? String)
                ?? (tlsSettings["fingerprint"] as? String)
            if let fingerprint, !fingerprint.isEmpty {
                tls["utls"] = [
                    "enabled": true,
                    "fingerprint": fingerprint,
                ]
            }

            if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty {
                tls["alpn"] = alpn
            }

            if security == "reality" {
                var reality: [String: Any] = ["enabled": true]
                if let pbk = realitySettings["publicKey"] as? String, !pbk.isEmpty {
                    reality["public_key"] = pbk
                }
                if let sid = realitySettings["shortId"] as? String {
                    let hex = String(sid.filter(\.isHexDigit))
                    if !hex.isEmpty {
                        reality["short_id"] = hex
                    }
                }
                tls["reality"] = reality
            }

            outbound["tls"] = tls
        }

        if let transport = xrayTransport(network: network, stream: stream) {
            // Reality + explicit stream-one → auto (TheTochka / lx framing quirk).
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
        } else {
            let n = network.lowercased()
            if !(n == "tcp" || n == "raw" || n.isEmpty) {
                // Unknown / unsupported transport must not silently become plain TCP.
                return nil
            }
        }

        switch XrayMuxAndMask.apply(from: xray, into: &outbound) {
        case .ok:
            return outbound
        case .unsupported:
            return nil
        }
    }

    private static func xrayTransport(network: String, stream: [String: Any]) -> [String: Any]? {
        switch network {
        case "ws", "websocket":
            let ws = (stream["wsSettings"] as? [String: Any]) ?? [:]
            var transport: [String: Any] = ["type": "ws"]
            if let path = ws["path"] as? String, !path.isEmpty {
                transport["path"] = path
            }
            if let headers = ws["headers"] as? [String: String], let host = headers["Host"] ?? headers["host"] {
                transport["headers"] = ["Host": host]
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
            } else {
                transport["mode"] = "auto"
            }
            // Preserve `extra` object keys and merge sibling tuning (scMaxEachPostBytes, …).
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
            if ((header["type"] as? String) ?? "none").lowercased() == "http" {
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
            return nil
        default:
            return nil
        }
    }
}
