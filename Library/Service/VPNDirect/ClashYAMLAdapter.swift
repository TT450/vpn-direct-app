import Foundation

/// Minimal Clash / Mihomo YAML proxy importer (proxies only — no rule engine).
enum ClashYAMLAdapter {
    private static let nestRoots: Set<String> = [
        "ws-opts", "grpc-opts", "reality-opts", "plugin-opts", "headers", "h2-opts", "http-opts",
    ]

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
        var attrs = flattenAliases(proxy)
        let hasReality = attrs["pbk"] != nil
            || attrs["public-key"] != nil
            || attrs.keys.contains(where: { $0.hasPrefix("reality-opts.") })
        switch type {
        case "vless":
            return NormalizedNode(
                name: name,
                protocolID: .vless,
                server: server,
                port: port,
                transport: VPNDirectTransportID(rawValue: attrs["network"] ?? "tcp"),
                security: (attrs["tls"] == "true" || hasReality) ? (hasReality ? .reality : .tls) : .none,
                uuid: attrs["uuid"],
                attributes: attrs
            )
        case "vmess":
            return NormalizedNode(
                name: name,
                protocolID: .vmess,
                server: server,
                port: port,
                transport: VPNDirectTransportID(rawValue: attrs["network"] ?? "tcp"),
                security: attrs["tls"] == "true" || hasReality ? (hasReality ? .reality : .tls) : .none,
                uuid: attrs["uuid"],
                attributes: attrs
            )
        case "trojan":
            attrs["password"] = attrs["password"] ?? ""
            return NormalizedNode(name: name, protocolID: .trojan, server: server, port: port, security: .tls, attributes: attrs)
        case "ss", "shadowsocks":
            attrs["method"] = attrs["cipher"] ?? attrs["method"] ?? ""
            attrs["password"] = attrs["password"] ?? ""
            return NormalizedNode(name: name, protocolID: .shadowsocks, server: server, port: port, attributes: attrs)
        case "hysteria2", "hy2":
            attrs["password"] = attrs["password"] ?? attrs["auth"] ?? ""
            return NormalizedNode(name: name, protocolID: .hysteria2, server: server, port: port, transport: .quic, security: .tls, attributes: attrs)
        case "hysteria":
            attrs["auth"] = attrs["auth"] ?? attrs["auth_str"] ?? ""
            return NormalizedNode(name: name, protocolID: .hysteria, server: server, port: port, transport: .quic, security: .tls, attributes: attrs)
        case "tuic":
            return NormalizedNode(name: name, protocolID: .tuic, server: server, port: port, transport: .quic, security: .tls, uuid: attrs["uuid"], attributes: attrs)
        case "anytls":
            attrs["password"] = attrs["password"] ?? ""
            return NormalizedNode(name: name, protocolID: .anytls, server: server, port: port, security: .tls, attributes: attrs)
        case "wireguard":
            attrs["private_key"] = attrs["private-key"] ?? attrs["private_key"] ?? ""
            attrs["peer_public_key"] = attrs["public-key"] ?? attrs["public_key"] ?? ""
            attrs["local_address"] = attrs["ip"] ?? attrs["address"] ?? "10.0.0.2/32"
            return NormalizedNode(name: name, protocolID: .wireguard, server: server, port: port, attributes: attrs)
        case "socks5", "socks":
            return NormalizedNode(name: name, protocolID: .socks, server: server, port: port, attributes: attrs)
        case "http":
            return NormalizedNode(name: name, protocolID: .http, server: server, port: port, attributes: attrs)
        default:
            throw VPNDirectCoreError.unsupportedFeature(component: "clash", detail: "Unsupported proxy type \(type)")
        }
    }

    /// Map nested Clash keys onto share-link style aliases used by UniversalOutboundBuilder.
    private static func flattenAliases(_ proxy: [String: String]) -> [String: String] {
        var attrs = proxy
        if let path = proxy["ws-opts.path"] ?? proxy["path"] {
            attrs["path"] = path
        }
        if let host = proxy["ws-opts.headers.host"] ?? proxy["ws-opts.headers.Host"] ?? proxy["headers.host"] ?? proxy["headers.Host"] {
            attrs["host"] = host
            attrs["Host"] = host
        }
        if let service = proxy["grpc-opts.grpc-service-name"] ?? proxy["grpc-opts.service_name"] {
            attrs["service_name"] = service
            attrs["grpc-service-name"] = service
        }
        if let pbk = proxy["reality-opts.public-key"] ?? proxy["public-key"] {
            attrs["pbk"] = pbk
            attrs["public-key"] = pbk
        }
        if let sid = proxy["reality-opts.short-id"] ?? proxy["short-id"] {
            attrs["sid"] = sid
            attrs["short-id"] = sid
        }
        if let fp = proxy["client-fingerprint"] ?? proxy["fingerprint"] {
            attrs["fp"] = fp
        }
        if let pluginOpts = nestedPluginOpts(proxy) {
            attrs["plugin_opts"] = pluginOpts
            attrs["plugin-opts"] = pluginOpts
        }
        return attrs
    }

    private static func nestedPluginOpts(_ proxy: [String: String]) -> String? {
        let prefix = "plugin-opts."
        let pairs = proxy
            .filter { $0.key.hasPrefix(prefix) }
            .map { "\($0.key.dropFirst(prefix.count))=\($0.value)" }
            .sorted()
        if !pairs.isEmpty { return pairs.joined(separator: ";") }
        return proxy["plugin-opts"]
    }

    /// Very small YAML subset parser for Clash `proxies:` list of maps, including nested opts.
    private static func extractProxyMaps(from text: String) -> [[String: String]] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inProxies = false
        var proxies: [[String: String]] = []
        var current: [String: String]?
        var currentIndent = 0
        // Stack of (indent, dottedPrefix) for nested maps like reality-opts / ws-opts / headers.
        var nestStack: [(indent: Int, prefix: String)] = []

        func flush() {
            if let current, current["type"] != nil, current["server"] != nil {
                proxies.append(current)
            }
        }

        func nestPrefix(at indent: Int) -> String {
            while let last = nestStack.last, last.indent >= indent {
                nestStack.removeLast()
            }
            return nestStack.last?.prefix ?? ""
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

            let indent = line.prefix(while: { $0 == " " }).count
            if indent == 0, trimmed.hasSuffix(":"), !trimmed.hasPrefix("-") {
                flush()
                break
            }

            if trimmed.hasPrefix("- ") {
                flush()
                current = [:]
                currentIndent = indent
                nestStack.removeAll()
                let rest = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if rest.contains(":"), !rest.hasPrefix("{") {
                    let kv = splitKV(rest)
                    current?[kv.0] = kv.1
                } else if rest.hasPrefix("{"), rest.hasSuffix("}") {
                    current = parseInlineMap(rest)
                }
                continue
            }

            guard current != nil, indent > currentIndent else { continue }

            let prefix = nestPrefix(at: indent)
            let kv = splitKV(trimmed)
            let isMapStart = kv.1.isEmpty && trimmed.hasSuffix(":")
            let keyLeaf = kv.0

            if isMapStart, nestRoots.contains(keyLeaf) || keyLeaf == "headers" {
                let nextPrefix = prefix.isEmpty ? keyLeaf : "\(prefix).\(keyLeaf)"
                nestStack.append((indent: indent, prefix: nextPrefix))
                continue
            }

            let fullKey = prefix.isEmpty ? keyLeaf : "\(prefix).\(keyLeaf)"
            current?[fullKey] = kv.1
            // Also keep leaf key for shallow consumers when not ambiguous.
            if prefix.isEmpty {
                current?[keyLeaf] = kv.1
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
