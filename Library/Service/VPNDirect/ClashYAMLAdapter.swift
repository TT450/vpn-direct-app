import Foundation

/// Minimal Clash / Mihomo YAML proxy importer (proxies only — no rule engine).
enum ClashYAMLAdapter {
    static func parse(_ text: String) throws -> NormalizedSubscription {
        let proxies = extractProxyMaps(from: text)
        guard !proxies.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }
        var endpoints: [NormalizedNode] = []
        for proxy in proxies {
            if let node = try? mapProxy(proxy) {
                endpoints.append(node)
            }
        }
        guard !endpoints.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }
        let location = NormalizedLocation(
            id: "clash",
            name: "Clash",
            kind: .country,
            strategy: endpoints.count > 1 ? .urltest : .single,
            endpoints: endpoints
        )
        return NormalizedSubscription(name: "Clash", locations: [location])
    }

    private static func mapProxy(_ proxy: [String: String]) throws -> NormalizedNode {
        let type = (proxy["type"] ?? "").lowercased()
        let name = proxy["name"] ?? type
        let server = proxy["server"] ?? ""
        let port = Int(proxy["port"] ?? "") ?? 0
        guard !server.isEmpty, port > 0 else {
            throw VPNDirectCoreError.malformedConfig(component: "clash", detail: "Missing server/port")
        }
        if EndpointValidator.isBlockedLoopbackHost(server) {
            throw VPNDirectCoreError.unsupportedFeature(component: "clash", detail: "Loopback rejected")
        }
        var attrs = proxy
        switch type {
        case "vless":
            return NormalizedNode(
                name: name,
                protocolID: .vless,
                server: server,
                port: port,
                transport: VPNDirectTransportID(rawValue: proxy["network"] ?? proxy["type"] ?? "tcp"),
                security: (proxy["tls"] == "true" || proxy["reality-opts"] != nil) ? .tls : .none,
                uuid: proxy["uuid"],
                attributes: attrs
            )
        case "vmess":
            return NormalizedNode(
                name: name,
                protocolID: .vmess,
                server: server,
                port: port,
                transport: VPNDirectTransportID(rawValue: proxy["network"] ?? "tcp"),
                security: proxy["tls"] == "true" ? .tls : .none,
                uuid: proxy["uuid"],
                attributes: attrs
            )
        case "trojan":
            attrs["password"] = proxy["password"] ?? ""
            return NormalizedNode(name: name, protocolID: .trojan, server: server, port: port, security: .tls, attributes: attrs)
        case "ss", "shadowsocks":
            attrs["method"] = proxy["cipher"] ?? proxy["method"] ?? ""
            attrs["password"] = proxy["password"] ?? ""
            return NormalizedNode(name: name, protocolID: .shadowsocks, server: server, port: port, attributes: attrs)
        case "hysteria2", "hy2":
            attrs["password"] = proxy["password"] ?? proxy["auth"] ?? ""
            return NormalizedNode(name: name, protocolID: .hysteria2, server: server, port: port, transport: .quic, security: .tls, attributes: attrs)
        case "hysteria":
            attrs["auth"] = proxy["auth"] ?? proxy["auth_str"] ?? ""
            return NormalizedNode(name: name, protocolID: .hysteria, server: server, port: port, transport: .quic, security: .tls, attributes: attrs)
        case "tuic":
            return NormalizedNode(name: name, protocolID: .tuic, server: server, port: port, transport: .quic, security: .tls, uuid: proxy["uuid"], attributes: attrs)
        case "anytls":
            attrs["password"] = proxy["password"] ?? ""
            return NormalizedNode(name: name, protocolID: .anytls, server: server, port: port, security: .tls, attributes: attrs)
        case "wireguard":
            attrs["private_key"] = proxy["private-key"] ?? proxy["private_key"] ?? ""
            attrs["peer_public_key"] = proxy["public-key"] ?? proxy["public_key"] ?? ""
            attrs["local_address"] = proxy["ip"] ?? proxy["address"] ?? "10.0.0.2/32"
            return NormalizedNode(name: name, protocolID: .wireguard, server: server, port: port, attributes: attrs)
        case "socks5", "socks":
            return NormalizedNode(name: name, protocolID: .socks, server: server, port: port, attributes: attrs)
        case "http":
            return NormalizedNode(name: name, protocolID: .http, server: server, port: port, attributes: attrs)
        default:
            throw VPNDirectCoreError.unsupportedFeature(component: "clash", detail: "Unsupported proxy type \(type)")
        }
    }

    /// Very small YAML subset parser for Clash `proxies:` list of maps.
    private static func extractProxyMaps(from text: String) -> [[String: String]] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inProxies = false
        var proxies: [[String: String]] = []
        var current: [String: String]?
        var currentIndent = 0

        func flush() {
            if let current, current["type"] != nil, current["server"] != nil {
                proxies.append(current)
            }
        }

        for rawLine in lines {
            let line = rawLine.replacingOccurrences(of: "\t", with: "  ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if !inProxies {
                if trimmed == "proxies:" || trimmed.hasPrefix("proxies:") {
                    inProxies = true
                }
                continue
            }

            // Left proxies section when a top-level key appears.
            let indent = line.prefix(while: { $0 == " " }).count
            if indent == 0, trimmed.hasSuffix(":"), !trimmed.hasPrefix("-") {
                flush()
                break
            }

            if trimmed.hasPrefix("- ") {
                flush()
                current = [:]
                currentIndent = indent
                let rest = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if rest.contains(":"), !rest.hasPrefix("{") {
                    let kv = splitKV(rest)
                    current?[kv.0] = kv.1
                } else if rest.hasPrefix("{"), rest.hasSuffix("}") {
                    // Inline map: { name: x, type: ss, ... }
                    current = parseInlineMap(rest)
                }
                continue
            }

            if current != nil, indent > currentIndent {
                let kv = splitKV(trimmed)
                current?[kv.0] = kv.1
            }
        }
        flush()
        return proxies
    }

    private static func splitKV(_ line: String) -> (String, String) {
        let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
        var value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }
        return (key, value)
    }

    private static func parseInlineMap(_ braced: String) -> [String: String] {
        var result: [String: String] = [:]
        let inner = braced.dropFirst().dropLast()
        for part in inner.split(separator: ",") {
            let kv = splitKV(String(part))
            if !kv.0.isEmpty { result[kv.0] = kv.1 }
        }
        return result
    }
}
