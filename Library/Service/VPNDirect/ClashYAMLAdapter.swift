import Foundation
#if canImport(Yams)
import Yams
#endif

/// Clash / Mihomo YAML proxy importer (proxies only — no rule engine).
///
/// Prefers Yams when linked; falls back to a hardened subset parser for quoted
/// values, inline arrays, booleans, and nested opts lists.
public enum ClashYAMLAdapter {
    private static let nestRoots: Set<String> = [
        "ws-opts", "grpc-opts", "reality-opts", "plugin-opts", "headers", "h2-opts", "http-opts",
    ]

    public static func parse(_ text: String) throws -> NormalizedSubscription {
        var proxies = extractProxyMapsViaYams(from: text)
        if proxies.isEmpty {
            proxies = extractProxyMaps(from: text)
        }
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
        // server/port/name/type live on NormalizedNode; keep them out of attribute fail-closed scans
        for key in ["server", "port", "name", "type"] {
            attrs.removeValue(forKey: key)
        }
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
        if let path = proxy["ws-opts.path"] ?? proxy["h2-opts.path"] ?? proxy["http-opts.path"] ?? proxy["path"] {
            attrs["path"] = path
        }
        if let host = proxy["ws-opts.headers.host"] ?? proxy["ws-opts.headers.Host"]
            ?? proxy["headers.host"] ?? proxy["headers.Host"]
            ?? proxy["h2-opts.host"] ?? proxy["http-opts.host"]
        {
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
        // Normalize YAML booleans already stored as strings.
        for key in ["tls", "udp", "skip-cert-verify", "allow-insecure"] {
            if let v = attrs[key] {
                attrs[key] = normalizeBoolString(v)
            }
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

    // MARK: - Yams preferred path

    private static func extractProxyMapsViaYams(from text: String) -> [[String: String]] {
        #if canImport(Yams)
        guard let root = try? Yams.compose(yaml: text),
              let mapping = root.mapping,
              let proxiesNode = mapping["proxies"],
              let sequence = proxiesNode.sequence
        else {
            return []
        }
        var proxies: [[String: String]] = []
        for item in sequence {
            guard let proxyMapping = item.mapping else { continue }
            let flat = flattenYamsMapping(proxyMapping)
            if flat["type"] != nil, flat["server"] != nil {
                proxies.append(flat)
            }
        }
        return proxies
        #else
        return []
        #endif
    }

    #if canImport(Yams)
    private static func flattenYamsMapping(_ mapping: Node.Mapping, prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        for (keyNode, valueNode) in mapping {
            let keyLeaf = (keyNode.string ?? "").lowercased()
            guard !keyLeaf.isEmpty else { continue }
            let fullKey = prefix.isEmpty ? keyLeaf : "\(prefix).\(keyLeaf)"
            if let nested = valueNode.mapping {
                result.merge(flattenYamsMapping(nested, prefix: fullKey)) { _, new in new }
            } else if let seq = valueNode.sequence {
                let joined = seq.compactMap { yamsScalarString($0) }.joined(separator: ",")
                result[fullKey] = joined
                if prefix.isEmpty {
                    result[keyLeaf] = joined
                }
            } else if let scalar = yamsScalarString(valueNode) {
                let normalized = normalizeBoolString(scalar)
                result[fullKey] = normalized
                if prefix.isEmpty {
                    result[keyLeaf] = normalized
                }
            }
        }
        return result
    }

    private static func yamsScalarString(_ node: Node) -> String? {
        if let s = node.string { return s }
        if let b = node.bool { return b ? "true" : "false" }
        if let i = node.int { return String(i) }
        if case let .scalar(scalar) = node {
            return scalar.string
        }
        return nil
    }
    #endif

    /// Very small YAML subset parser for Clash `proxies:` list of maps, including nested opts.
    /// Used when Yams is unavailable or returns an empty proxy list.
    private static func extractProxyMaps(from text: String) -> [[String: String]] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inProxies = false
        var proxies: [[String: String]] = []
        var current: [String: String]?
        var currentIndent = 0
        // Stack of (indent, dottedPrefix) for nested maps like reality-opts / ws-opts / headers.
        var nestStack: [(indent: Int, prefix: String)] = []
        // When a nested key opened an array (`path:` then `- /a`), accumulate here.
        var arrayKey: String?
        var arrayIndent = 0
        var arrayValues: [String] = []

        func flushArray() {
            guard let key = arrayKey, !arrayValues.isEmpty else {
                arrayKey = nil
                arrayValues = []
                return
            }
            current?[key] = arrayValues.joined(separator: ",")
            let leaf = key.split(separator: ".").last.map(String.init) ?? key
            if nestStack.isEmpty {
                current?[leaf] = arrayValues.joined(separator: ",")
            }
            arrayKey = nil
            arrayValues = []
        }

        func flush() {
            flushArray()
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
                // Nested array item under an open list key (not a new proxy entry).
                if current != nil, indent > currentIndent, let key = arrayKey, indent > arrayIndent {
                    let rest = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !rest.hasPrefix("{") {
                        arrayValues.append(unquoteYAML(rest))
                        _ = key
                        continue
                    }
                }

                flush()
                current = [:]
                currentIndent = indent
                nestStack.removeAll()
                arrayKey = nil
                arrayValues = []
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

            // Close array when indent retreats.
            if let key = arrayKey, indent <= arrayIndent, !trimmed.hasPrefix("- ") {
                flushArray()
                _ = key
            }

            let prefix = nestPrefix(at: indent)
            let kv = splitKV(trimmed)
            let isMapStart = kv.1.isEmpty && trimmed.hasSuffix(":")
            let keyLeaf = kv.0

            if isMapStart, nestRoots.contains(keyLeaf) || keyLeaf == "headers" {
                let nextPrefix = prefix.isEmpty ? keyLeaf : "\(prefix).\(keyLeaf)"
                nestStack.append((indent: indent, prefix: nextPrefix))
                flushArray()
                continue
            }

            if isMapStart {
                // Key with no inline value — may start a nested list (e.g. h2-opts.path: then - items).
                let fullKey = prefix.isEmpty ? keyLeaf : "\(prefix).\(keyLeaf)"
                flushArray()
                arrayKey = fullKey
                arrayIndent = indent
                arrayValues = []
                continue
            }

            flushArray()
            let fullKey = prefix.isEmpty ? keyLeaf : "\(prefix).\(keyLeaf)"
            current?[fullKey] = kv.1
            if prefix.isEmpty {
                current?[keyLeaf] = kv.1
            }
        }
        flush()
        return proxies
    }

    private static func splitKV(_ line: String) -> (String, String) {
        guard let colon = firstUnquotedColon(in: line) else {
            return (line.trimmingCharacters(in: .whitespaces).lowercased(), "")
        }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
        var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        value = normalizeValue(value)
        return (key, value)
    }

    private static func normalizeValue(_ raw: String) -> String {
        var value = unquoteYAML(raw)
        if value.hasPrefix("["), value.hasSuffix("]") {
            value = parseInlineArray(value).joined(separator: ",")
        }
        return normalizeBoolString(value)
    }

    private static func normalizeBoolString(_ value: String) -> String {
        switch value.lowercased() {
        case "true", "yes", "on": return "true"
        case "false", "no", "off": return "false"
        default: return value
        }
    }

    private static func unquoteYAML(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        // Strip surrounding quotes; honor simple escapes.
        if value.count >= 2 {
            if value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
                value = value
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
                    .replacingOccurrences(of: "\\n", with: "\n")
            } else if value.hasPrefix("'"), value.hasSuffix("'") {
                value = String(value.dropFirst().dropLast())
                value = value.replacingOccurrences(of: "''", with: "'")
            }
        }
        return value
    }

    private static func firstUnquotedColon(in line: String) -> String.Index? {
        var inSingle = false
        var inDouble = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"", !inSingle { inDouble.toggle() }
            else if ch == "'", !inDouble { inSingle.toggle() }
            else if ch == ":", !inSingle, !inDouble {
                return i
            }
            i = line.index(after: i)
        }
        return nil
    }

    private static func parseInlineArray(_ bracketed: String) -> [String] {
        guard bracketed.hasPrefix("["), bracketed.hasSuffix("]") else { return [] }
        let inner = String(bracketed.dropFirst().dropLast())
        return splitCSVRespectingQuotes(inner).map { unquoteYAML($0) }.filter { !$0.isEmpty }
    }

    private static func parseInlineMap(_ braced: String) -> [String: String] {
        var result: [String: String] = [:]
        let inner = String(braced.dropFirst().dropLast())
        for part in splitCSVRespectingQuotes(inner) {
            let kv = splitKV(part)
            if !kv.0.isEmpty { result[kv.0] = kv.1 }
        }
        return result
    }

    /// Split on commas not inside quotes or nested []/{}.
    private static func splitCSVRespectingQuotes(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var depth = 0
        for ch in text {
            if ch == "\"", !inSingle { inDouble.toggle(); current.append(ch); continue }
            if ch == "'", !inDouble { inSingle.toggle(); current.append(ch); continue }
            if !inSingle, !inDouble {
                if ch == "[" || ch == "{" { depth += 1; current.append(ch); continue }
                if ch == "]" || ch == "}" { depth = max(0, depth - 1); current.append(ch); continue }
                if ch == ",", depth == 0 {
                    parts.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                    continue
                }
            }
            current.append(ch)
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { parts.append(trimmed) }
        return parts
    }
}
