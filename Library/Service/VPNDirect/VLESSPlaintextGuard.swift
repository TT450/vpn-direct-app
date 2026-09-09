import Foundation

/// INCY-style fail-closed: reject public VLESS without TLS/Reality and without VLESS encryption.
/// Credentials would otherwise travel in the clear on the wire.
public enum VLESSPlaintextGuard {
    public static func isNonPublicHost(_ host: String) -> Bool {
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if h.isEmpty { return true }
        if EndpointValidator.isBlockedLoopbackHost(h) { return true }
        if h.hasSuffix(".local") || h.hasSuffix(".lan") { return true }
        if h == "0.0.0.0" || h == "::" { return true }
        // RFC1918 / link-local / ULA
        if h.hasPrefix("10.") { return true }
        if h.hasPrefix("192.168.") { return true }
        if h.hasPrefix("169.254.") { return true }
        if h.hasPrefix("fc") || h.hasPrefix("fd") { return true } // rough IPv6 ULA
        if h.hasPrefix("fe80:") { return true }
        if let m = h.range(of: #"^172\.(1[6-9]|2[0-9]|3[0-1])\."#, options: .regularExpression) {
            _ = m
            return true
        }
        return false
    }

    public static func hasMeaningfulEncryption(_ encryption: String?) -> Bool {
        let value = (encryption ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !value.isEmpty && value != "none"
    }

    /// True when connecting would expose VLESS identity in plaintext to a public address.
    public static func isInsecurePublicVLESS(
        server: String,
        hasTLSOrReality: Bool,
        encryption: String?
    ) -> Bool {
        if hasTLSOrReality { return false }
        if hasMeaningfulEncryption(encryption) { return false }
        if isNonPublicHost(server) { return false }
        return true
    }

    public static func userMessage(tag: String) -> String {
        let name = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "VLESS" : name
        return String(
            localized: "Сервер «\(label)» настроен без TLS/Reality и без шифрования VLESS. Такие подключения к публичным адресам не запускаются — данные для входа ушли бы открытым текстом. Сообщите провайдеру: на этом сервере нужно включить TLS, Reality или шифрование VLESS."
        )
    }

    /// Scan a sing-box JSON config for insecure public VLESS leaf outbounds.
    public static func firstInsecureOutboundTag(inJSON json: String) -> String? {
        insecureOutboundTags(inJSON: json).first
    }

    public static func insecureOutboundTags(inJSON json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = root["outbounds"] as? [[String: Any]]
        else { return [] }

        var tags: [String] = []
        for outbound in outbounds {
            let type = ((outbound["type"] as? String) ?? "").lowercased()
            guard type == "vless" else { continue }
            let server = ((outbound["server"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !server.isEmpty else { continue }
            let tls = outbound["tls"] as? [String: Any]
            let tlsEnabled = (tls?["enabled"] as? Bool) ?? false
            let reality = tls?["reality"] as? [String: Any]
            let realityEnabled = (reality?["enabled"] as? Bool) ?? (reality != nil)
            let hasTLSOrReality = tlsEnabled || realityEnabled
            let encryption = outbound["encryption"] as? String
            if isInsecurePublicVLESS(server: server, hasTLSOrReality: hasTLSOrReality, encryption: encryption) {
                let tag = ((outbound["tag"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                tags.append(tag.isEmpty ? server : tag)
            }
        }
        return tags
    }

    /// Drop insecure public VLESS leaves and scrub them from selector/urltest member lists.
    /// Keeps the rest of the graph usable (INCY blocks only the bad node, not every server).
    public static func strippingInsecurePublicVLESS(fromJSON json: String) throws -> String {
        let bad = Set(insecureOutboundTags(inJSON: json))
        guard !bad.isEmpty else { return json }
        guard let data = json.data(using: .utf8),
              var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var outbounds = root["outbounds"] as? [[String: Any]]
        else { return json }

        outbounds = outbounds.compactMap { outbound in
            let tag = ((outbound["tag"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let type = ((outbound["type"] as? String) ?? "").lowercased()
            if type == "vless", !tag.isEmpty, bad.contains(tag) {
                return nil
            }
            // Also drop by matching server fingerprint when tag empty — already in bad via server string.
            if type == "vless" {
                let server = ((outbound["server"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let tls = outbound["tls"] as? [String: Any]
                let tlsEnabled = (tls?["enabled"] as? Bool) ?? false
                let reality = tls?["reality"] as? [String: Any]
                let realityEnabled = (reality?["enabled"] as? Bool) ?? (reality != nil)
                if isInsecurePublicVLESS(
                    server: server,
                    hasTLSOrReality: tlsEnabled || realityEnabled,
                    encryption: outbound["encryption"] as? String
                ) {
                    return nil
                }
            }
            if type == "selector" || type == "urltest",
               var members = outbound["outbounds"] as? [String]
            {
                members = members.filter { !bad.contains($0) }
                guard !members.isEmpty else { return nil }
                var copy = outbound
                copy["outbounds"] = members
                return copy
            }
            return outbound
        }
        root["outbounds"] = outbounds
        let cleaned = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        guard let text = String(data: cleaned, encoding: .utf8) else { return json }
        // If a named bad tag was the only remaining path, surface the original error.
        if let still = firstInsecureOutboundTag(inJSON: text) {
            throw VPNDirectCoreError.plaintextVLESS(tag: still)
        }
        if outbounds.contains(where: { (($0["type"] as? String) ?? "").lowercased() == "vless" }) == false,
           outbounds.contains(where: {
               let t = (($0["type"] as? String) ?? "").lowercased()
               return t != "direct" && t != "block" && t != "dns" && t != "selector" && t != "urltest"
           }) == false
        {
            throw VPNDirectCoreError.plaintextVLESS(tag: bad.first ?? "VLESS")
        }
        return text
    }
}
