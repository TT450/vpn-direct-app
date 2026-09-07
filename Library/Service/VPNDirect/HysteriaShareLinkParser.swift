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
        if let password = outbound["password"] as? String { attributes["password"] = password }
        if let auth = outbound["auth_str"] as? String { attributes["auth"] = auth }
        if let value = outbound["up_mbps"] as? Int { attributes["up"] = String(value) }
        if let value = outbound["down_mbps"] as? Int { attributes["down"] = String(value) }
        if let values = outbound["server_ports"] as? [String], !values.isEmpty {
            attributes["server_ports"] = values.joined(separator: ",")
        }
        if let value = outbound["hop_interval"] as? String { attributes["hop_interval"] = value }
        if let value = outbound["hop_interval_max"] as? String { attributes["hop_interval_max"] = value }
        if let value = outbound["network"] as? String { attributes["outbound_network"] = value }
        if let value = outbound["bbr_profile"] as? String { attributes["bbr_profile"] = value }
        if let value = outbound["brutal_debug"] as? Bool { attributes["brutal_debug"] = value ? "true" : "false" }
        if let value = outbound["disable_chrome_parrot"] as? Bool { attributes["disable_chrome_parrot"] = value ? "true" : "false" }

        if let tls = outbound["tls"] as? [String: Any] {
            if let sni = tls["server_name"] as? String { attributes["sni"] = sni }
            if let insecure = tls["insecure"] as? Bool { attributes["insecure"] = insecure ? "true" : "false" }
            if let alpn = tls["alpn"] as? [String], !alpn.isEmpty { attributes["alpn"] = alpn.joined(separator: ",") }
        }
        if let obfs = outbound["obfs"] as? [String: Any], let t = obfs["type"] as? String {
            attributes["obfs"] = t
            if let p = obfs["password"] as? String { attributes["obfs_password"] = p }
            if let p = obfs["min_packet_size"] as? Int { attributes["obfs_min_packet_size"] = String(p) }
            if let p = obfs["max_packet_size"] as? Int { attributes["obfs_max_packet_size"] = String(p) }
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
            source: link
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

        // HY2's official URI scheme defines 443 when omitted. Hysteria v1 requires an explicit port.
        let port: Int
        if let explicitPort = url.port {
            port = explicitPort
        } else if isV2 {
            port = 443
        } else {
            return nil
        }

        let items = URLComponents(string: trimmed)?.queryItems ?? []
        var query: [String: String] = [:]
        for item in items {
            if let value = item.value { query[item.name.lowercased()] = value }
        }

        let user = url.user.map { $0.removingPercentEncoding ?? $0 } ?? ""
        let passwordPart = url.password.map { $0.removingPercentEncoding ?? $0 } ?? ""
        let userInfoAuth: String = {
            if !user.isEmpty, !passwordPart.isEmpty { return "\(user):\(passwordPart)" }
            if !user.isEmpty { return user }
            if !passwordPart.isEmpty { return passwordPart }
            return ""
        }()
        // Hysteria v1 commonly carries auth in the query. HY2 uses URI userinfo, while realm-style
        // and some ecosystem exports use `auth=`; preserve it instead of inventing credentials.
        let auth = query["auth"]?.removingPercentEncoding ?? userInfoAuth

        var tls: [String: Any] = ["enabled": true]
        if let sni = query["sni"] ?? query["peer"], !sni.isEmpty { tls["server_name"] = sni }
        if let raw = query["insecure"] ?? query["allowinsecure"] {
            switch raw.lowercased() {
            case "1", "true", "yes": tls["insecure"] = true
            case "0", "false", "no": tls["insecure"] = false
            default: return nil
            }
        }
        // QUIC / Hysteria cannot use uTLS; `fp=` is not translated into a different TLS feature.
        if let alpn = query["alpn"], !alpn.isEmpty {
            tls["alpn"] = alpn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }

        let fragmentName: String = {
            guard let raw = url.fragment else { return fallbackTag }
            let decoded = (raw.removingPercentEncoding ?? raw).trimmingCharacters(in: .whitespacesAndNewlines)
            return decoded.isEmpty ? fallbackTag : decoded
        }()

        if isV2 {
            var outbound: [String: Any] = [
                "type": "hysteria2",
                "tag": fragmentName,
                "server": host,
                "server_port": port,
                "tls": tls,
            ]
            if !auth.isEmpty { outbound["password"] = auth }

            if let obfs = query["obfs"], !obfs.isEmpty, obfs.lowercased() != "none" {
                let typeName = obfs.lowercased()
                guard typeName == "salamander" || typeName == "gecko" else { return nil }
                if typeName == "gecko", !VPNDirectCoreCapabilities.current.hysteria2Obfuscations.contains("gecko") { return nil }
                var object: [String: Any] = ["type": typeName]
                if let password = query["obfs-password"] ?? query["obfs_password"], !password.isEmpty {
                    object["password"] = password
                }
                if typeName == "gecko" {
                    if let raw = query["obfs-min-packet-size"] ?? query["obfs_min_packet_size"], let value = Int(raw) { object["min_packet_size"] = value }
                    if let raw = query["obfs-max-packet-size"] ?? query["obfs_max_packet_size"], let value = Int(raw) { object["max_packet_size"] = value }
                }
                outbound["obfs"] = object
            } else if let password = query["obfs-password"] ?? query["obfs_password"], !password.isEmpty {
                // Official HY2 URI requires an explicit `obfs=` selector. A password alone is ambiguous.
                return nil
            }

            if let up = query["upmbps"] ?? query["up_mbps"] {
                guard let value = Int(up), value >= 0 else { return nil }
                outbound["up_mbps"] = value
            }
            if let down = query["downmbps"] ?? query["down_mbps"] {
                guard let value = Int(down), value >= 0 else { return nil }
                outbound["down_mbps"] = value
            }
            if let value = query["server_ports"] ?? query["ports"], !value.isEmpty {
                outbound["server_ports"] = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
            if let value = query["hop_interval"] ?? query["hop-interval"], !value.isEmpty { outbound["hop_interval"] = value }
            if let value = query["hop_interval_max"] ?? query["hop-interval-max"], !value.isEmpty { outbound["hop_interval_max"] = value }
            if let value = query["network"], !value.isEmpty { outbound["network"] = value }
            if let value = query["bbr_profile"] ?? query["bbr-profile"], !value.isEmpty { outbound["bbr_profile"] = value }
            if let raw = query["brutal_debug"] ?? query["brutal-debug"] { outbound["brutal_debug"] = ["1", "true", "yes"].contains(raw.lowercased()) }
            if let raw = query["disable_chrome_parrot"] ?? query["disable-chrome-parrot"] { outbound["disable_chrome_parrot"] = ["1", "true", "yes"].contains(raw.lowercased()) }
            return outbound
        }

        // Hysteria v1 URI requires bandwidth values. Do not fabricate 100 Mbps when absent.
        guard let upRaw = query["upmbps"] ?? query["up_mbps"], let up = Int(upRaw), up > 0,
              let downRaw = query["downmbps"] ?? query["down_mbps"], let down = Int(downRaw), down > 0
        else { return nil }

        var outbound: [String: Any] = [
            "type": "hysteria",
            "tag": fragmentName,
            "server": host,
            "server_port": port,
            "up_mbps": up,
            "down_mbps": down,
            "tls": tls,
        ]
        if !auth.isEmpty { outbound["auth_str"] = auth }
        if let obfs = query["obfs"], !obfs.isEmpty { outbound["obfs"] = obfs }
        if let value = query["server_ports"], !value.isEmpty {
            outbound["server_ports"] = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        if let value = query["hop_interval"] ?? query["hop-interval"], !value.isEmpty { outbound["hop_interval"] = value }
        if let value = query["network"], !value.isEmpty { outbound["network"] = value }
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
        guard let port = intValue(settings["port"]), (1...65535).contains(port) else { return nil }

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

        var obfsType: String?
        var obfsPassword: String?
        var obfsMinPacketSize: Int?
        var obfsMaxPacketSize: Int?
        if let finalmask = stream["finalmask"] as? [String: Any] {
            let udpList = (finalmask["udp"] as? [[String: Any]]) ?? []
            if let first = udpList.first {
                obfsType = ((first["type"] as? String) ?? "").lowercased()
                let obfsSettings = (first["settings"] as? [String: Any]) ?? [:]
                obfsPassword = stringValue(obfsSettings["password"])
                obfsMinPacketSize = intValue(obfsSettings["min_packet_size"])
                obfsMaxPacketSize = intValue(obfsSettings["max_packet_size"])
            }
        }
        if obfsPassword == nil {
            obfsPassword = stringValue(hy["obfsPassword"]) ?? stringValue(hy["obfs_password"]) ?? stringValue(settings["obfsPassword"])
        }
        if obfsType == nil || obfsType?.isEmpty == true {
            obfsType = stringValue(hy["obfs"])?.lowercased() ?? stringValue(settings["obfs"])?.lowercased()
        }
        obfsMinPacketSize = obfsMinPacketSize ?? intValue(hy["obfs_min_packet_size"]) ?? intValue(settings["obfs_min_packet_size"])
        obfsMaxPacketSize = obfsMaxPacketSize ?? intValue(hy["obfs_max_packet_size"]) ?? intValue(settings["obfs_max_packet_size"])

        if let typeName = obfsType, !typeName.isEmpty {
            if isV2 {
                guard typeName == "salamander" || typeName == "gecko" else { return nil }
                if typeName == "gecko", !VPNDirectCoreCapabilities.current.hysteria2Obfuscations.contains("gecko") { return nil }
            }
        }

        let tlsSettings = (stream["tlsSettings"] as? [String: Any]) ?? [:]
        let realitySettings = (stream["realitySettings"] as? [String: Any]) ?? [:]
        var tls: [String: Any] = ["enabled": true]
        if let sni = stringValue(tlsSettings["serverName"]) ?? stringValue(realitySettings["serverName"]), !sni.isEmpty { tls["server_name"] = sni }
        if let insecure = tlsSettings["allowInsecure"] as? Bool { tls["insecure"] = insecure }
        if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty {
            tls["alpn"] = alpn
        } else if let alpn = tlsSettings["alpn"] as? String, !alpn.isEmpty {
            tls["alpn"] = alpn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }

        let tag = (xray["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTag
        var outbound: [String: Any] = [
            "type": isV2 ? "hysteria2" : "hysteria",
            "tag": tag,
            "server": address,
            "server_port": port,
            "tls": tls,
        ]
        if let auth, !auth.isEmpty { outbound[isV2 ? "password" : "auth_str"] = auth }

        if let up = intValue(hy["up_mbps"]) ?? intValue(settings["up_mbps"]) { outbound["up_mbps"] = up }
        if let down = intValue(hy["down_mbps"]) ?? intValue(settings["down_mbps"]) { outbound["down_mbps"] = down }
        if let ports = stringListValue(hy["server_ports"] ?? settings["server_ports"]), !ports.isEmpty { outbound["server_ports"] = ports }
        if let value = stringValue(hy["hop_interval"] ?? settings["hop_interval"]) { outbound["hop_interval"] = value }
        if isV2, let value = stringValue(hy["hop_interval_max"] ?? settings["hop_interval_max"]) { outbound["hop_interval_max"] = value }
        if let value = stringValue(hy["network"] ?? settings["network"]) { outbound["network"] = value }

        if isV2 {
            if let typeName = obfsType, !typeName.isEmpty {
                var object: [String: Any] = ["type": typeName]
                if let obfsPassword, !obfsPassword.isEmpty { object["password"] = obfsPassword }
                if typeName == "gecko" {
                    if let obfsMinPacketSize { object["min_packet_size"] = obfsMinPacketSize }
                    if let obfsMaxPacketSize { object["max_packet_size"] = obfsMaxPacketSize }
                }
                outbound["obfs"] = object
            }
            if let value = stringValue(hy["bbr_profile"] ?? settings["bbr_profile"]) { outbound["bbr_profile"] = value }
            if let value = boolValue(hy["brutal_debug"] ?? settings["brutal_debug"]) { outbound["brutal_debug"] = value }
            if let value = boolValue(hy["disable_chrome_parrot"] ?? settings["disable_chrome_parrot"]) { outbound["disable_chrome_parrot"] = value }
        } else if let obfsPassword, !obfsPassword.isEmpty {
            outbound["obfs"] = obfsPassword
        } else if let obfsType, !obfsType.isEmpty {
            outbound["obfs"] = obfsType
        }
        return outbound
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? Double { return Int(value) }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool { return value }
        if let value = raw as? NSNumber { return value.boolValue }
        if let value = raw as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "on": return true
            case "0", "false", "no", "off": return false
            default: return nil
            }
        }
        return nil
    }

    private static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    private static func stringListValue(_ raw: Any?) -> [String]? {
        if let values = raw as? [String] { return values.filter { !$0.isEmpty } }
        if let values = raw as? [Any] {
            let mapped = values.compactMap(stringValue)
            return mapped.isEmpty ? nil : mapped
        }
        if let value = stringValue(raw) {
            let mapped = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return mapped.isEmpty ? nil : mapped
        }
        return nil
    }
}
