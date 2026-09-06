import Foundation

/// Parses `hysteria://`, `hysteria2://`, `hy2://` share links (TheTochka / Happ semantics).
public struct HysteriaShareLinkParser: VPNDirectParser {
    public init() {}

    public var supportedSchemes: [String] { ["hysteria", "hysteria2", "hy2"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        guard let outbound = HysteriaOutboundFactory.fromShareLink(link, fallbackTag: "proxy") else {
            throw VPNDirectCoreError.unsupportedFeature(
                component: "hysteria",
                detail: "Invalid or incomplete Hysteria share link"
            )
        }
        let type = (outbound["type"] as? String) ?? "hysteria2"
        let server = outbound["server"] as? String ?? ""
        let port = outbound["server_port"] as? Int ?? 0
        if EndpointValidator.isBlockedLoopbackHost(server) {
            throw VPNDirectCoreError.unsupportedFeature(
                component: "hysteria",
                detail: "Loopback / stub Hysteria endpoint rejected"
            )
        }
        let name = (outbound["tag"] as? String) ?? "Hysteria"
        var attributes: [String: String] = [:]
        if let obfs = outbound["obfs"] as? [String: Any], let t = obfs["type"] as? String {
            attributes["obfs"] = t
        } else if let obfs = outbound["obfs"] as? String {
            attributes["obfs"] = obfs
        }
        return NormalizedNode(
            name: name,
            protocolID: VPNDirectProtocolID(rawValue: type),
            server: server,
            port: port,
            transport: .quic,
            security: .tls,
            obfuscation: attributes["obfs"].map { VPNDirectObfuscationID(rawValue: $0) },
            attributes: attributes,
            source: link,
            outbound: outbound
        )
    }
}

/// Shared Hysteria / HY2 outbound construction for share links and Xray JSON.
enum HysteriaOutboundFactory {
    static func fromShareLink(_ link: String, fallbackTag: String) -> [String: Any]? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let isV2 = lower.hasPrefix("hysteria2://") || lower.hasPrefix("hy2://")
        guard lower.hasPrefix("hysteria://") || isV2 else { return nil }
        guard let url = URL(string: trimmed) else { return nil }

        let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !host.isEmpty, !EndpointValidator.isBlockedLoopbackHost(host) else { return nil }
        let port = url.port ?? 443
        let user = url.user.map { $0.removingPercentEncoding ?? $0 } ?? ""
        let passwordPart = url.password.map { $0.removingPercentEncoding ?? $0 } ?? ""
        let auth: String
        if !user.isEmpty, !passwordPart.isEmpty {
            auth = "\(user):\(passwordPart)"
        } else if !user.isEmpty {
            auth = user
        } else if !passwordPart.isEmpty {
            auth = passwordPart
        } else {
            auth = ""
        }
        guard !auth.isEmpty else { return nil }

        let items = URLComponents(string: trimmed)?.queryItems ?? []
        var query: [String: String] = [:]
        for item in items {
            if let value = item.value {
                query[item.name.lowercased()] = value
            }
        }

        let sni = query["sni"] ?? query["peer"] ?? host
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": sni,
        ]
        if query["insecure"] == "1" || query["allowinsecure"] == "1" {
            tls["insecure"] = true
        }
        // QUIC / Hysteria cannot use uTLS — ignore fp= from share links.
        if let alpn = query["alpn"], !alpn.isEmpty {
            tls["alpn"] = alpn.split(separator: ",").map { String($0) }
        } else if isV2 {
            tls["alpn"] = ["h3"]
        }

        let fragmentName: String = {
            guard let raw = url.fragment else { return fallbackTag }
            let decoded = (raw.removingPercentEncoding ?? raw)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return decoded.isEmpty ? fallbackTag : decoded
        }()

        if isV2 {
            var outbound: [String: Any] = [
                "type": "hysteria2",
                "tag": fragmentName,
                "server": host,
                "server_port": port,
                "password": auth,
                "tls": tls,
            ]
            let obfsPass = query["obfs-password"] ?? query["obfs_password"] ?? query["obfspassword"]
            let obfs = query["obfs"]
            if let obfsPass, !obfsPass.isEmpty {
                outbound["obfs"] = [
                    "type": (obfs?.isEmpty == false ? obfs! : "salamander"),
                    "password": obfsPass,
                ]
            } else if let obfs, !obfs.isEmpty, obfs.lowercased() != "salamander", obfs.lowercased() != "none" {
                outbound["obfs"] = [
                    "type": "salamander",
                    "password": obfs,
                ]
            }
            if let up = Int(query["upmbps"] ?? query["up_mbps"] ?? "") {
                outbound["up_mbps"] = up
            }
            if let down = Int(query["downmbps"] ?? query["down_mbps"] ?? "") {
                outbound["down_mbps"] = down
            }
            return outbound
        }

        var outbound: [String: Any] = [
            "type": "hysteria",
            "tag": fragmentName,
            "server": host,
            "server_port": port,
            "auth_str": auth,
            "up_mbps": Int(query["upmbps"] ?? query["up_mbps"] ?? "") ?? 100,
            "down_mbps": Int(query["downmbps"] ?? query["down_mbps"] ?? "") ?? 100,
            "tls": tls,
        ]
        if let obfs = query["obfs"], !obfs.isEmpty {
            outbound["obfs"] = obfs
        }
        return outbound
    }

    /// Remnawave / Happ XRAY JSON: `protocol: hysteria` with `settings.version` 1|2.
    static func fromXray(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let hy = (stream["hysteriaSettings"] as? [String: Any]) ?? [:]
        let proto = ((xray["protocol"] as? String) ?? "").lowercased()

        let address = ((settings["address"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !EndpointValidator.isBlockedLoopbackHost(address) else { return nil }
        let port = intValue(settings["port"]) ?? 443

        let versionHint = intValue(settings["version"])
            ?? intValue(hy["version"])
            ?? (proto.contains("2") ? 2 : 1)
        let isV2 = versionHint >= 2 || proto == "hysteria2"

        let auth = stringValue(hy["auth"])
            ?? stringValue(hy["auth_str"])
            ?? stringValue(hy["password"])
            ?? stringValue(settings["auth"])
            ?? stringValue(settings["auth_str"])
            ?? stringValue(settings["password"])
            ?? ""
        guard !auth.isEmpty else { return nil }

        var obfsType: String?
        var obfsPassword: String?
        if let finalmask = stream["finalmask"] as? [String: Any] {
            let udpList = (finalmask["udp"] as? [[String: Any]]) ?? []
            if let first = udpList.first {
                obfsType = ((first["type"] as? String) ?? "").lowercased()
                let obfsSettings = (first["settings"] as? [String: Any]) ?? [:]
                obfsPassword = stringValue(obfsSettings["password"])
            }
        }
        if obfsPassword == nil || obfsPassword?.isEmpty == true {
            obfsPassword = stringValue(hy["obfsPassword"])
                ?? stringValue(hy["obfs_password"])
                ?? stringValue(settings["obfsPassword"])
            if obfsType == nil || obfsType?.isEmpty == true {
                let rawObfs = stringValue(hy["obfs"]) ?? stringValue(settings["obfs"])
                if let rawObfs, rawObfs.lowercased() == "salamander" {
                    obfsType = "salamander"
                } else if let rawObfs, obfsPassword == nil {
                    obfsPassword = rawObfs
                    obfsType = "salamander"
                }
            }
        }

        if let typeName = obfsType, typeName == "gecko",
           !VPNDirectCoreCapabilities.current.hysteria2Obfuscations.contains("gecko")
        {
            return nil
        }

        let tlsSettings = (stream["tlsSettings"] as? [String: Any]) ?? [:]
        let realitySettings = (stream["realitySettings"] as? [String: Any]) ?? [:]
        let sni = stringValue(tlsSettings["serverName"])
            ?? stringValue(realitySettings["serverName"])
            ?? address
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": sni,
        ]
        if let insecure = tlsSettings["allowInsecure"] as? Bool {
            tls["insecure"] = insecure
        }
        // Hysteria uses QUIC — ignore Remnawave fingerprint / uTLS.
        if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty {
            tls["alpn"] = alpn
        } else if let alpn = tlsSettings["alpn"] as? String, !alpn.isEmpty {
            tls["alpn"] = alpn.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
        } else if isV2 {
            tls["alpn"] = ["h3"]
        }

        let tag = (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag

        if isV2 {
            var outbound: [String: Any] = [
                "type": "hysteria2",
                "tag": tag,
                "server": address,
                "server_port": port,
                "password": auth,
                "tls": tls,
            ]
            if let obfsPassword, !obfsPassword.isEmpty {
                let typeName = (obfsType?.isEmpty == false) ? obfsType! : "salamander"
                outbound["obfs"] = [
                    "type": typeName,
                    "password": obfsPassword,
                ]
            }
            if let up = intValue(hy["up_mbps"]) ?? intValue(settings["up_mbps"]) {
                outbound["up_mbps"] = up
            }
            if let down = intValue(hy["down_mbps"]) ?? intValue(settings["down_mbps"]) {
                outbound["down_mbps"] = down
            }
            if outbound["up_mbps"] == nil { outbound["up_mbps"] = 100 }
            if outbound["down_mbps"] == nil { outbound["down_mbps"] = 100 }
            return outbound
        }

        var outbound: [String: Any] = [
            "type": "hysteria",
            "tag": tag,
            "server": address,
            "server_port": port,
            "auth_str": auth,
            "up_mbps": intValue(hy["up_mbps"]) ?? intValue(settings["up_mbps"]) ?? 100,
            "down_mbps": intValue(hy["down_mbps"]) ?? intValue(settings["down_mbps"]) ?? 100,
            "tls": tls,
        ]
        if let obfsPassword, !obfsPassword.isEmpty {
            outbound["obfs"] = obfsPassword
        }
        return outbound
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? Double { return Int(value) }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}
