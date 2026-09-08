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

    /// Authority parse that tolerates unencoded `/` (and similar) inside userinfo.
    /// Foundation `URL` treats the first `/` after `scheme://` as path, which breaks
    /// public HY2/Trojan dumps like `hy2://pass/with/slash@host:443`.
    static func splitUserInfoHostPort(
        from link: String,
        defaultPort: Int
    ) -> (userInfo: String?, host: String, port: Int)? {
        guard let schemeRange = link.range(of: "://") else { return nil }
        var authority = String(link[schemeRange.upperBound...])
        if let hash = authority.firstIndex(of: "#") {
            authority = String(authority[..<hash])
        }
        if let query = authority.firstIndex(of: "?") {
            authority = String(authority[..<query])
        }

        let userInfo: String?
        var hostPort: String
        if let at = authority.lastIndex(of: "@") {
            let rawUser = String(authority[..<at])
            userInfo = rawUser.isEmpty ? nil : (rawUser.removingPercentEncoding ?? rawUser)
            hostPort = String(authority[authority.index(after: at)...])
        } else {
            userInfo = nil
            hostPort = authority
        }
        // Drop path after host:port (feeds often use `host:443/`).
        if let slash = hostPort.firstIndex(of: "/") {
            hostPort = String(hostPort[..<slash])
        }

        let host: String
        let port: Int
        if hostPort.hasPrefix("["), let close = hostPort.firstIndex(of: "]") {
            host = String(hostPort[hostPort.index(after: hostPort.startIndex)..<close])
            let rest = hostPort[hostPort.index(after: close)...]
            port = rest.hasPrefix(":") ? (Int(rest.dropFirst()) ?? defaultPort) : defaultPort
        } else if let colon = hostPort.lastIndex(of: ":"),
                  let parsed = Int(hostPort[hostPort.index(after: colon)...]),
                  parsed > 0, parsed <= 65535,
                  !hostPort[hostPort.index(after: colon)...].contains(":")
        {
            host = String(hostPort[..<colon])
            port = parsed
        } else {
            host = hostPort
            port = defaultPort
        }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return nil }
        return (userInfo, trimmedHost, port)
    }

    /// Happ / v2rayN encode Cloudflare WS early-data as `path=/?ed=2560` (or separate `ed=`).
    static func normalizeWebSocketEarlyData(into attrs: inout [String: String]) {
        if let path = attrs["path"], let range = path.range(of: "?ed=") {
            let barePath = String(path[..<range.lowerBound])
            let edValue = String(path[range.upperBound...])
                .split(separator: "&", maxSplits: 1)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            attrs["path"] = barePath.isEmpty ? "/" : barePath
            if let edValue, !edValue.isEmpty, attrs["ed"] == nil {
                attrs["ed"] = edValue
            }
        }
        if let ed = attrs["ed"] ?? attrs["max_early_data"] ?? attrs["maxEarlyData"],
           !ed.isEmpty
        {
            attrs["max_early_data"] = ed
            if attrs["early_data_header_name"] == nil, attrs["earlyDataHeaderName"] == nil {
                attrs["early_data_header_name"] = "Sec-WebSocket-Protocol"
            }
        }
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

        // Happ / sing-box / v2rayN URI form: vmess://uuid@host:port?encryption=&security=&type=#name
        if payload.contains("@"), !isLikelyBase64JSONPayload(payload) {
            return try parseURIForm(trimmed)
        }

        // Classic v2rayN: vmess://base64(json)
        guard let data = Data(base64Encoded: payload)
            ?? Data(base64Encoded: payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // Last chance: URI with unusual base64-looking userinfo already rejected above; try URI anyway.
            if payload.contains("@") {
                return try parseURIForm(trimmed)
            }
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Invalid base64 JSON or URI")
        }
        return try parseJSONForm(json, source: trimmed)
    }

    /// True when payload looks like standard base64 JSON (no `@` authority).
    private func isLikelyBase64JSONPayload(_ payload: String) -> Bool {
        let head = payload.split(separator: "#", maxSplits: 1).first.map(String.init) ?? payload
        if head.contains("@") { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=-_\n\r")
        return head.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func parseJSONForm(_ json: [String: Any], source: String) throws -> NormalizedNode {
        let host = (json["add"] as? String) ?? ""
        let port = Int("\(json["port"] ?? "")") ?? 0
        guard !host.isEmpty, (1...65535).contains(port) else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing add/port")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "vmess", detail: "Loopback rejected")
        }
        let uuid = (json["id"] as? String) ?? ""
        guard !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing id")
        }
        let name = (json["ps"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "VMess"
        var attrs: [String: String] = [:]
        for (k, v) in json {
            if let s = v as? String { attrs[k.lowercased()] = s }
            else if let n = v as? NSNumber { attrs[k.lowercased()] = n.stringValue }
        }
        // Cipher lives in scy; do not treat JSON "security" as AEAD if it looks like TLS mode.
        if let scy = attrs["scy"], !scy.isEmpty {
            attrs["encryption"] = scy
        }
        let net = ((json["net"] as? String) ?? attrs["type"] ?? "tcp").lowercased()
        let tls = ((json["tls"] as? String) ?? "").lowercased()
        let security: VPNDirectSecurityID
        if tls == "tls" || tls == "reality" {
            security = VPNDirectSecurityID(rawValue: tls)
            attrs["security"] = tls
        } else {
            security = .none
            attrs["security"] = "none"
        }
        if attrs["type"] == nil { attrs["type"] = net }
        return NormalizedNode(
            name: name,
            protocolID: .vmess,
            server: host,
            port: port,
            transport: VPNDirectTransportID(rawValue: net),
            security: security,
            uuid: uuid,
            attributes: attrs,
            source: source
        )
    }

    private func parseURIForm(_ link: String) throws -> NormalizedNode {
        guard let components = URLComponents(string: link) ?? {
            // Spaces / emoji in fragment occasionally need encoding for older Foundation paths.
            guard let hash = link.firstIndex(of: "#") else { return nil }
            let base = String(link[..<hash])
            let frag = String(link[link.index(after: hash)...])
                .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
            return URLComponents(string: base + "#" + frag)
        }() else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Invalid URI")
        }
        let host = (components.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let port = components.port ?? 443
        let uuid = (components.user?.removingPercentEncoding ?? components.user ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, (1...65535).contains(port) else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing host/port")
        }
        guard !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing uuid")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "vmess", detail: "Loopback rejected")
        }

        let query = ShareLinkURI.queryMap(from: link)
        var attrs = query

        // URI: encryption/scy = AEAD cipher; security = none|tls|reality (TLS layer).
        let cipher = (query["encryption"] ?? query["scy"] ?? "auto").trimmingCharacters(in: .whitespacesAndNewlines)
        attrs["encryption"] = cipher.isEmpty ? "auto" : cipher
        attrs["scy"] = attrs["encryption"]!

        let tlsMode = (query["security"] ?? "none").lowercased()
        attrs["security"] = tlsMode
        if let sni = query["sni"] ?? query["peer"], !sni.isEmpty { attrs["sni"] = sni }
        if let fp = query["fp"] ?? query["fingerprint"], !fp.isEmpty { attrs["fp"] = fp }
        if let alpn = query["alpn"], !alpn.isEmpty { attrs["alpn"] = alpn }
        if let pbk = query["pbk"], !pbk.isEmpty { attrs["pbk"] = pbk }
        if let sid = query["sid"], !sid.isEmpty { attrs["sid"] = sid }
        if let aid = query["aid"] ?? query["alterid"] ?? query["alterId"], !aid.isEmpty { attrs["aid"] = aid }

        let transportRaw = (query["type"] ?? query["net"] ?? "tcp").lowercased()
        attrs["type"] = transportRaw
        attrs["net"] = transportRaw
        if let path = query["path"], !path.isEmpty { attrs["path"] = path }
        if let hostHeader = query["host"], !hostHeader.isEmpty { attrs["host"] = hostHeader }
        if let service = query["serviceName"] ?? query["service_name"], !service.isEmpty {
            attrs["service_name"] = service
        }
        if let mode = query["mode"], !mode.isEmpty { attrs["mode"] = mode }
        ShareLinkURI.normalizeWebSocketEarlyData(into: &attrs)

        let security: VPNDirectSecurityID
        switch tlsMode {
        case "tls": security = .tls
        case "reality": security = .reality
        default: security = .none
        }

        let name: String = {
            if let frag = components.fragment?
                .removingPercentEncoding ?? components.fragment
            {
                let trimmedName = frag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty { return trimmedName }
            }
            return "VMess"
        }()

        return NormalizedNode(
            name: name,
            protocolID: .vmess,
            server: host,
            port: port,
            transport: VPNDirectTransportID(rawValue: transportRaw),
            security: security,
            uuid: uuid,
            attributes: attrs,
            source: link
        )
    }
}

// MARK: - Trojan

public struct TrojanShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["trojan"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed) ?? {
            guard let hash = trimmed.firstIndex(of: "#") else { return nil }
            let base = String(trimmed[..<hash])
            let frag = String(trimmed[trimmed.index(after: hash)...])
                .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
            return URLComponents(string: base + "#" + frag)
        }() else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Invalid URL")
        }
        let host = (components.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let port = components.port ?? 443
        guard !host.isEmpty, (1...65535).contains(port) else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Missing host/port")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "trojan", detail: "Loopback rejected")
        }
        let password = (components.user?.removingPercentEncoding ?? components.user ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Missing password")
        }

        var attrs = ShareLinkURI.queryMap(from: trimmed)
        ShareLinkURI.normalizeWebSocketEarlyData(into: &attrs)
        attrs["password"] = password
        // Happ / free-pool aliases
        if attrs["path"] == nil, let wspath = attrs["wspath"], !wspath.isEmpty {
            attrs["path"] = wspath
        }
        if (attrs["type"] == nil || attrs["type"]?.isEmpty == true),
           let ws = attrs["ws"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           ws == "1" || ws == "true" || ws == "yes"
        {
            attrs["type"] = "ws"
        }
        if let cs = attrs["cs"], !cs.isEmpty, attrs["cipher_suites"] == nil {
            attrs["cipher_suites"] = cs
        }

        let tlsMode = (attrs["security"] ?? "tls").lowercased()
        let security: VPNDirectSecurityID
        switch tlsMode {
        case "none", "":
            security = .none
        case "reality":
            security = .reality
        default:
            security = .tls
            attrs["security"] = "tls"
        }

        let transport = VPNDirectTransportID(rawValue: attrs["type"] ?? attrs["net"] ?? "tcp")
        let name: String = {
            if let frag = components.fragment?.removingPercentEncoding ?? components.fragment {
                let trimmedName = frag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty { return trimmedName }
            }
            return "Trojan"
        }()

        return NormalizedNode(
            name: name,
            protocolID: .trojan,
            server: host,
            port: port,
            transport: transport,
            security: security,
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

        // Happ / panel mislabels: VLESS-shaped URI published as ss://uuid@host?security=tls&type=ws…
        if looksLikeVLESSShapedSS(trimmed) {
            let rewritten = "vless://" + String(trimmed.dropFirst("ss://".count))
            return try VLESSShareLinkParser().parseShareLink(rewritten)
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

    /// UUID userinfo + TLS/WS query is VLESS URI shape, not SIP002 Shadowsocks.
    private func looksLikeVLESSShapedSS(_ link: String) -> Bool {
        guard let components = URLComponents(string: link) else { return false }
        let user = (components.user ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !user.contains(":"), user.contains("-"), user.count >= 32 else { return false }
        let query = ShareLinkURI.queryMap(from: link)
        let security = (query["security"] ?? "").lowercased()
        let type = (query["type"] ?? query["network"] ?? "").lowercased()
        let encryption = (query["encryption"] ?? "").lowercased()
        if security == "tls" || security == "reality" || security == "none" { return true }
        if !type.isEmpty, type != "tcp" { return true }
        if encryption == "none" { return true }
        return false
    }

    private func decodeB64(_ s: String) -> String? {
        let cleaned = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = String(repeating: "=", count: (4 - cleaned.count % 4) % 4)
        guard let data = Data(base64Encoded: cleaned + pad) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - ShadowsocksR (`ssr://` → Core `type: shadowsocksr`)

public struct ShadowsocksRShareLinkParser: VPNDirectParser {
    public init() {}
    public var supportedSchemes: [String] { ["ssr"] }

    public func parseShareLink(_ link: String) throws -> NormalizedNode {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("ssr://") else {
            throw VPNDirectCoreError.malformedConfig(component: "ssr", detail: "Not an ssr:// link")
        }
        var payload = String(trimmed.dropFirst("ssr://".count))
        var fragmentName: String?
        if let hash = payload.firstIndex(of: "#") {
            let frag = String(payload[payload.index(after: hash)...])
            fragmentName = (frag.removingPercentEncoding ?? frag)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            payload = String(payload[..<hash])
        }
        guard let decoded = decodeURLSafeBase64(payload)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !decoded.isEmpty
        else {
            throw VPNDirectCoreError.malformedConfig(component: "ssr", detail: "Invalid base64 payload")
        }

        // host:port:protocol:method:obfs:base64pass/?params
        let bodyAndQuery = decoded.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let main = String(bodyAndQuery[0])
        let parts = main.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 6 else {
            throw VPNDirectCoreError.malformedConfig(
                component: "ssr",
                detail: "Expected host:port:protocol:method:obfs:password"
            )
        }
        let host = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(parts[1]), (1...65535).contains(port), !host.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "ssr", detail: "Missing host/port")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "ssr", detail: "Loopback rejected")
        }
        let protocolName = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let method = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let obfs = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordB64 = parts[5...].joined(separator: ":")
        guard let password = decodeURLSafeBase64(passwordB64), !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "ssr", detail: "Missing password")
        }
        guard !method.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "ssr", detail: "Missing method")
        }

        var attrs: [String: String] = [
            "method": method,
            "password": password,
            "protocol": protocolName.isEmpty ? "origin" : protocolName,
            "obfs": obfs.isEmpty ? "plain" : obfs,
        ]

        if bodyAndQuery.count > 1 {
            var queryPart = String(bodyAndQuery[1])
            if queryPart.hasPrefix("?") { queryPart = String(queryPart.dropFirst()) }
            for item in queryPart.split(separator: "&") {
                let kv = item.split(separator: "=", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                let key = kv[0].lowercased()
                let raw = kv[1].removingPercentEncoding ?? kv[1]
                switch key {
                case "obfsparam", "obfs_param":
                    attrs["obfs_param"] = decodeURLSafeBase64(raw) ?? raw
                case "protoparam", "protocol_param", "protocolparam":
                    attrs["protocol_param"] = decodeURLSafeBase64(raw) ?? raw
                case "remarks", "remark":
                    if fragmentName == nil || fragmentName?.isEmpty == true {
                        fragmentName = decodeURLSafeBase64(raw) ?? raw
                    }
                case "group":
                    attrs["group"] = decodeURLSafeBase64(raw) ?? raw
                default:
                    attrs[key] = raw
                }
            }
        }

        let name = (fragmentName?.isEmpty == false) ? fragmentName! : "ShadowsocksR"
        return NormalizedNode(
            name: name,
            protocolID: .shadowsocksr,
            server: host,
            port: port,
            attributes: attrs,
            source: trimmed
        )
    }

    private func decodeURLSafeBase64(_ raw: String) -> String? {
        var cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Strip non-base64 noise some feeds append.
        cleaned = cleaned.filter { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" }
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
        guard let components = URLComponents(string: trimmed) ?? {
            guard let hash = trimmed.firstIndex(of: "#") else { return nil }
            let base = String(trimmed[..<hash])
            let frag = String(trimmed[trimmed.index(after: hash)...])
                .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
            return URLComponents(string: base + "#" + frag)
        }() else {
            throw VPNDirectCoreError.malformedConfig(component: "tuic", detail: "Invalid URL")
        }
        let host = (components.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let port = components.port ?? 443
        guard !host.isEmpty, (1...65535).contains(port) else {
            throw VPNDirectCoreError.malformedConfig(component: "tuic", detail: "Missing host/port")
        }
        if EndpointValidator.isBlockedLoopbackHost(host) {
            throw VPNDirectCoreError.unsupportedFeature(component: "tuic", detail: "Loopback rejected")
        }
        let uuid = (components.user?.removingPercentEncoding ?? components.user ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let password = (components.password?.removingPercentEncoding ?? components.password ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        if !password.isEmpty { attrs["password"] = password }
        if let cc = attrs["congestion_control"] ?? attrs["congestion-control"] {
            attrs["congestion_control"] = cc
        }
        // Normalize insecure aliases used by Happ / Clash-style TUIC URIs.
        if let raw = attrs["allow_insecure"] ?? attrs["allowinsecure"] ?? attrs["insecure"] {
            attrs["insecure"] = raw
        }
        let name: String = {
            if let frag = components.fragment?.removingPercentEncoding ?? components.fragment {
                let trimmedName = frag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty { return trimmedName }
            }
            return "TUIC"
        }()
        return NormalizedNode(
            name: name,
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
        var attrs = ShareLinkURI.queryMap(from: trimmed)
        // Normalize share-link aliases used by Hiddify / WARP dumps / free pools.
        if attrs["peer_public_key"] == nil {
            attrs["peer_public_key"] = attrs["public_key"] ?? attrs["publickey"] ?? attrs["public-key"]
        }
        if attrs["private_key"] == nil {
            attrs["private_key"] = attrs["privatekey"] ?? attrs["private-key"]
        }
        if attrs["pre_shared_key"] == nil {
            attrs["pre_shared_key"] = attrs["preshared_key"] ?? attrs["presharedkey"] ?? attrs["preshared-key"]
        }
        if attrs["local_address"] == nil {
            attrs["local_address"] = attrs["address"] ?? attrs["ip"]
        }
        if attrs["allowed_ips"] == nil {
            attrs["allowed_ips"] = attrs["allowedips"]
        }
        if attrs["persistent_keepalive"] == nil, let keepalive = attrs["keepalive"] {
            attrs["persistent_keepalive"] = keepalive
        }
        // Hiddify junk-noise → AmneziaWG classic fields (when explicit jc/j* absent).
        if attrs["jc"] == nil, let count = attrs["wnoisecount"].flatMap(Int.init) {
            attrs["jc"] = String(count)
        } else if attrs["jc"] == nil, attrs["wnoise"] != nil {
            // Presence-only noise flag from free pools — map to a conservative classic junk count.
            attrs["jc"] = "4"
        }
        if attrs["jmin"] == nil || attrs["jmax"] == nil,
           let payload = attrs["wpayloadsize"], payload.contains("-")
        {
            let parts = payload.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                if attrs["jmin"] == nil { attrs["jmin"] = parts[0] }
                if attrs["jmax"] == nil { attrs["jmax"] = parts[1] }
            }
        } else if attrs["jmin"] == nil, let payload = attrs["wpayloadsize"].flatMap(Int.init) {
            attrs["jmin"] = String(payload)
            attrs["jmax"] = String(payload)
        }
        if let pk = url.user?.removingPercentEncoding ?? url.user, !pk.isEmpty {
            attrs["private_key"] = pk
        }
        let privateKey = attrs["private_key"] ?? ""
        let peerKey = attrs["peer_public_key"] ?? ""
        let local = (attrs["local_address"] ?? "10.0.0.2/32")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let forced = attrs["amnezia_version"]
        let claimedFromNoise = attrs["wnoise"] != nil || attrs["wnoisecount"] != nil || attrs["wpayloadsize"] != nil
        let options = try AmneziaWGEndpointOptions.fromFlatAttributes(
            privateKey: privateKey,
            peerPublicKey: peerKey,
            localAddress: Array(local),
            peerEndpoint: "\(host):\(port)",
            preSharedKey: attrs["pre_shared_key"],
            mtu: attrs["mtu"].flatMap(Int.init),
            attributes: attrs,
            forcedVersion: forced,
            claimedAWG: (isAWG || claimedFromNoise) && forced == nil
        )
        let inferred = try AmneziaWGEndpointOptions.inferAmneziaVersion(
            from: options,
            forced: forced,
            claimedAWG: (isAWG || claimedFromNoise) && forced == nil
        )
        var finalOptions = options
        if let inferred { finalOptions.amneziaVersion = inferred }
        let useAWG = inferred != nil || isAWG || claimedFromNoise
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
