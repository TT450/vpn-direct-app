import Foundation

/// Shared URI helpers for share-link parsers.
enum ShareLinkURI {
    static func queryMap(from urlString: String) -> [String: String] {
        var query: [String: String] = [:]
        for item in URLComponents(string: urlString)?.queryItems ?? [] {
            if let value = item.value {
                query[item.name.lowercased()] = value.removingPercentEncoding ?? value
            }
        }
        return query
    }

    static func fragmentName(from url: URL, fallback: String) -> String {
        guard let raw = url.fragment else { return fallback }
        let decoded = (raw.removingPercentEncoding ?? raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return decoded.isEmpty ? fallback : decoded
    }

    static func requireHostPort(_ url: URL, defaultPort: Int) throws -> (String, Int) {
        let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !host.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "uri", detail: "Missing host")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "uri", detail: "Loopback / stub endpoint rejected")
        }
        return (host, url.port ?? defaultPort)
    }
}

// MARK: - VMess

public struct VMessShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["vmess"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("vmess://") else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Not a vmess:// link")
        }
        let payload = String(trimmed.dropFirst("vmess://".count))
        guard let data = Data(base64Encoded: payload)
            ?? Data(base64Encoded: payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Invalid base64 JSON")
        }
        let host = (json["add"] as? String) ?? ""
        let port = Int("\(json["port"] ?? "")") ?? 0
        guard !host.isEmpty, port > 0 else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing add/port")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "vmess", detail: "Loopback rejected")
        }
        let uuid = (json["id"] as? String) ?? ""
        let name = (json["ps"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "VMess"
        var attrs: [String: String] = [:]
        for (k, v) in json {
            if let s = v as? String { attrs[k.lowercased()] = s }
            else if let n = v as? NSNumber { attrs[k.lowercased()] = n.stringValue }
        }
        let net = ((json["net"] as? String) ?? "tcp").lowercased()
        let tls = ((json["tls"] as? String) ?? "").lowercased()
        return NormalizedNode(
            name: name,
            protocolID: .vmess,
            server: host,
            port: port,
            transport: VPNDirectTransportID(rawValue: net),
            security: tls == "tls" ? .tls : .none,
            uuid: uuid,
            attributes: attrs,
            source: trimmed
        )
    }
}

// MARK: - Trojan

public struct TrojanShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["trojan"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 443)
        let password = (url.user?.removingPercentEncoding ?? url.user) ?? ""
        guard !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Missing password")
        }
        let query = ShareLinkURI.queryMap(from: trimmed)
        var attrs = query
        attrs["password"] = password
        let transport = VPNDirectTransportID(rawValue: query["type"] ?? "tcp")
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "Trojan"),
            protocolID: .trojan,
            server: host,
            port: port,
            transport: transport,
            security: .tls,
            attributes: attrs,
            source: trimmed
        )
    }
}

// MARK: - Shadowsocks

public struct ShadowsocksShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["ss"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("ss://") else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Not ss://")
        }
        // SIP002: ss://base64(method:password)@host:port#name  OR ss://base64(method:password@host:port)
        let withoutScheme = String(trimmed.dropFirst(5))
        let (main, fragment): (String, String?) = {
            if let idx = withoutScheme.firstIndex(of: "#") {
                return (String(withoutScheme[..<idx]), String(withoutScheme[withoutScheme.index(after: idx)...]))
            }
            return (withoutScheme, nil)
        }()

        var method = ""
        var password = ""
        var host = ""
        var port = 0
        var plugin: String?
        var pluginOpts: String?

        if main.contains("@") {
            let parts = main.split(separator: "@", maxSplits: 1).map(String.init)
            let userInfo = parts[0]
            let hostPort = parts.count > 1 ? parts[1] : ""
            let decodedUser: String
            if let d = decodeB64(userInfo), d.contains(":") {
                decodedUser = d
            } else {
                decodedUser = userInfo.removingPercentEncoding ?? userInfo
            }
            let cred = decodedUser.split(separator: ":", maxSplits: 1).map(String.init)
            method = cred.first ?? ""
            password = cred.count > 1 ? cred[1] : ""
            let hp = hostPort.split(separator: "?", maxSplits: 1).map(String.init)
            let endpoint = hp[0]
            if endpoint.contains(":") {
                let ep = endpoint.split(separator: ":", maxSplits: 1).map(String.init)
                host = ep[0]
                port = Int(ep[1]) ?? 0
            }
            if hp.count > 1 {
                let q = ShareLinkURI.queryMap(from: "ss://x?\(hp[1])")
                plugin = q["plugin"]
                pluginOpts = q["plugin-opts"] ?? q["plugin_opts"]
            }
        } else {
            let decoded = decodeB64(main) ?? ""
            // method:password@host:port
            guard let at = decoded.lastIndex(of: "@") else {
                throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Invalid legacy ss://")
            }
            let cred = String(decoded[..<at])
            let endpoint = String(decoded[decoded.index(after: at)...])
            let c = cred.split(separator: ":", maxSplits: 1).map(String.init)
            method = c.first ?? ""
            password = c.count > 1 ? c[1] : ""
            let ep = endpoint.split(separator: ":", maxSplits: 1).map(String.init)
            host = ep.first ?? ""
            port = ep.count > 1 ? (Int(ep[1]) ?? 0) : 0
        }

        guard !method.isEmpty, !password.isEmpty, !host.isEmpty, port > 0 else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Incomplete ss://")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "shadowsocks", detail: "Loopback rejected")
        }
        var attrs: [String: String] = ["method": method, "password": password]
        if let plugin { attrs["plugin"] = plugin }
        if let pluginOpts { attrs["plugin_opts"] = pluginOpts }
        let name = fragment.flatMap { ($0.removingPercentEncoding ?? $0).trimmingCharacters(in: .whitespacesAndNewlines) }
        return NormalizedNode(
            name: (name?.isEmpty == false ? name! : "Shadowsocks"),
            protocolID: .shadowsocks,
            server: host,
            port: port,
            attributes: attrs,
            source: trimmed
        )
    }

    private func decodeB64(_ s: String) -> String? {
        let cleaned = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = String(repeating: "=", count: (4 - cleaned.count % 4) % 4)
        guard let data = Data(base64Encoded: cleaned + pad) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - TUIC

public struct TUICShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["tuic"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "tuic", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 443)
        let uuid = url.user?.removingPercentEncoding ?? url.user ?? ""
        let password = url.password?.removingPercentEncoding ?? url.password ?? ""
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        if !password.isEmpty { attrs["password"] = password }
        if let cc = attrs["congestion_control"] ?? attrs["congestion-control"] {
            attrs["congestion_control"] = cc
        }
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "TUIC"),
            protocolID: .tuic,
            server: host,
            port: port,
            transport: .quic,
            security: .tls,
            uuid: uuid.isEmpty ? nil : uuid,
            attributes: attrs,
            source: trimmed
        )
    }
}

// MARK: - AnyTLS

public struct AnyTLSShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["anytls"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "anytls", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 443)
        let password = url.user?.removingPercentEncoding ?? url.user ?? ""
        guard !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "anytls", detail: "Missing password")
        }
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        attrs["password"] = password
        // Explicitly do not set client/device metadata attributes.
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "AnyTLS"),
            protocolID: .anytls,
            server: host,
            port: port,
            security: .tls,
            attributes: attrs,
            source: trimmed
        )
    }
}

// MARK: - WireGuard / AWG URI

public struct WireGuardShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["wireguard", "wg", "awg"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let isAWG = lower.hasPrefix("awg://")
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 51820)
        let query = ShareLinkURI.queryMap(from: trimmed)
        var attrs = query
        if let pk = url.user?.removingPercentEncoding ?? url.user, !pk.isEmpty {
            attrs["private_key"] = pk
        }
        let privateKey = attrs["private_key"] ?? ""
        let peerKey = attrs["peer_public_key"] ?? attrs["public_key"] ?? attrs["public-key"] ?? ""
        let local = (attrs["local_address"] ?? attrs["address"] ?? attrs["ip"] ?? "10.0.0.2/32")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let forced = attrs["amnezia_version"]
        let options = try AmneziaWGEndpointOptions.fromFlatAttributes(
            privateKey: privateKey,
            peerPublicKey: peerKey,
            localAddress: Array(local),
            peerEndpoint: "\(host):\(port)",
            preSharedKey: attrs["pre_shared_key"] ?? attrs["preshared_key"],
            mtu: attrs["mtu"].flatMap(Int.init),
            attributes: attrs,
            forcedVersion: forced,
            claimedAWG: isAWG && forced == nil
        )
        let inferred = try AmneziaWGEndpointOptions.inferAmneziaVersion(
            from: options,
            forced: forced,
            claimedAWG: isAWG && forced == nil
        )
        var finalOptions = options
        if let inferred { finalOptions.amneziaVersion = inferred }
        let useAWG = inferred != nil || isAWG
        if useAWG { attrs["amnezia_version"] = finalOptions.amneziaVersion }
        attrs["private_key"] = privateKey
        attrs["peer_public_key"] = peerKey
        attrs["local_address"] = local.joined(separator: ",")
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: useAWG ? "AmneziaWG" : "WireGuard"),
            protocolID: useAWG ? .amneziawg : .wireguard,
            server: host,
            port: port,
            transport: VPNDirectTransportID(rawValue: "udp"),
            attributes: attrs,
            source: trimmed,
            wireguardEndpoint: finalOptions
        )
    }
}

// MARK: - SOCKS / HTTP

public struct SOCKSShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["socks", "socks5", "socks4"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "socks", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 1080)
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        if let user = url.user { attrs["username"] = user.removingPercentEncoding ?? user }
        if let pass = url.password { attrs["password"] = pass.removingPercentEncoding ?? pass }
        let version = trimmed.lowercased().hasPrefix("socks4") ? "4" : "5"
        attrs["version"] = version
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "SOCKS"),
            protocolID: .socks,
            server: host,
            port: port,
            attributes: attrs,
            source: trimmed
        )
    }
}

public struct HTTPProxyShareLinkParser: VPNDirectParser {
    public init() {}
    /// Only treat as proxy when query contains `proxy=1` or path `/proxy` — avoids eating subscription https URLs.
    public var supportedSchemes: [String] { ["http-proxy", "https-proxy"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept http://user:pass@host:port/?proxy=1 and https-proxy://...
        let normalized: String = {
            let lower = trimmed.lowercased()
            if lower.hasPrefix("https-proxy://") {
                return "https://" + trimmed.dropFirst("https-proxy://".count)
            }
            if lower.hasPrefix("http-proxy://") {
                return "http://" + trimmed.dropFirst("http-proxy://".count)
            }
            return trimmed
        }()
        guard let url = URL(string: normalized) else {
            throw VPNDirectCoreError.malformedConfig(component: "http", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: normalized.lowercased().hasPrefix("https") ? 443 : 80)
        var attrs = ShareLinkURI.queryMap(from: normalized)
        if let user = url.user { attrs["username"] = user.removingPercentEncoding ?? user }
        if let pass = url.password { attrs["password"] = pass.removingPercentEncoding ?? pass }
        let security: VPNDirectSecurityID = normalized.lowercased().hasPrefix("https") ? .tls : .none
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "HTTP"),
            protocolID: .http,
            server: host,
            port: port,
            security: security,
            attributes: attrs,
            source: trimmed
        )
    }
}

// MARK: - SSH

public struct SSHShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["ssh"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "ssh", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 22)
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        if let user = url.user { attrs["user"] = user.removingPercentEncoding ?? user }
        if let pass = url.password { attrs["password"] = pass.removingPercentEncoding ?? pass }
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "SSH"),
            protocolID: .ssh,
            server: host,
            port: port,
            attributes: attrs,
            source: trimmed
        )
    }
}

// MARK: - ShadowTLS / Naive

public struct ShadowTLSShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["shadowtls"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowtls", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 443)
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        if let pass = url.user { attrs["password"] = pass.removingPercentEncoding ?? pass }
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "ShadowTLS"),
            protocolID: VPNDirectProtocolID(rawValue: "shadowtls"),
            server: host,
            port: port,
            security: .tls,
            attributes: attrs,
            source: trimmed
        )
    }
}

public struct NaiveProxyShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["naive", "naive+https", "naive+quic"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .replacingOccurrences(of: "naive+https://", with: "https://")
            .replacingOccurrences(of: "naive+quic://", with: "https://")
            .replacingOccurrences(of: "naive://", with: "https://")
        guard let url = URL(string: normalized) else {
            throw VPNDirectCoreError.malformedConfig(component: "naive", detail: "Invalid URL")
        }
        let (host, port) = try ShareLinkURI.requireHostPort(url, defaultPort: 443)
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        if let user = url.user { attrs["username"] = user.removingPercentEncoding ?? user }
        if let pass = url.password { attrs["password"] = pass.removingPercentEncoding ?? pass }
        attrs["network"] = trimmed.lowercased().contains("quic") ? "quic" : "https"
        return NormalizedNode(
            name: ShareLinkURI.fragmentName(from: url, fallback: "Naive"),
            protocolID: VPNDirectProtocolID(rawValue: "naive"),
            server: host,
            port: port,
            security: .tls,
            attributes: attrs,
            source: trimmed
        )
    }
}
