import Foundation
import Libbox

/// Converts classic VPN subscription payloads (base64 / plain share-link lists)
/// into a sing-box 1.13 JSON config suitable for remote profiles.
public enum SubscriptionConfigBuilder {
    public struct Result {
        public let name: String?
        public let json: String
        public let nodeCount: Int
        public let metadata: SubscriptionMetadata
    }

    public static func isHTTPURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    public static func suggestedName(for urlString: String, headers: [String: String] = [:]) -> String {
        resolveSubscriptionName(urlString: urlString, headers: headers, contentName: nil)
    }

    public static func resolveSubscriptionName(
        urlString: String,
        headers: [String: String] = [:],
        contentName: String?
    ) -> String {
        let meta = SubscriptionMetadata.parse(headers: headers)
        // profile-title may look like a domain (VPN-DIRECT.COM) — that is still the real name.
        if let title = SubscriptionMetadata.sanitizedTitle(meta.title) {
            return title
        }

        if let contentName, let title = SubscriptionMetadata.sanitizedTitle(contentName) {
            // Prefer content/header titles over URL host fallbacks even when domain-shaped.
            if !looksLikeHost(title) || title.contains(".") {
                return title
            }
        }

        if let headerName = nameFromHeaders(headers), let title = SubscriptionMetadata.sanitizedTitle(headerName) {
            return title
        }

        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL) else {
            return "Subscription"
        }

        if let fragment = url.fragment?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fragment.isEmpty,
           !looksLikeHost(fragment)
        {
            return fragment
        }

        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let rawValue = queryItems.first(where: {
               ["name", "title", "profile", "remark", "remarks"].contains($0.name.lowercased())
           })?.value
        {
            let queryName = (rawValue.removingPercentEncoding ?? rawValue)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !queryName.isEmpty {
                return queryName
            }
        }

        if let pathName = domainLikePathComponent(in: url) {
            return pathName
        }

        if let host = url.host, !host.isEmpty {
            return host
        }
        return "Subscription"
    }

    public static func fetchAndNormalize(url: String) async throws -> Result {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var lastError: Error = SubscriptionError.empty

        for agent in SubscriptionHTTP.userAgents {
            do {
                let response = try await SubscriptionHTTP.fetch(url: trimmedURL, userAgent: agent)
                do {
                    return try normalizeRemoteContent(response.body, sourceURL: trimmedURL, headers: response.headers)
                } catch {
                    lastError = error
                    if case SubscriptionError.panelRejected = error {
                        continue
                    }
                    // HTML browser page is not usable as a profile body.
                    if response.body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<!doctype")
                        || response.body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<html")
                    {
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    /// Accepts raw remote body: sing-box JSON, base64 share list, or plain share links.
    public static func normalizeRemoteContent(
        _ content: String,
        sourceURL: String = "",
        headers: [String: String] = [:]
    ) throws -> Result {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubscriptionError.empty
        }

        if looksLikeSingBoxJSON(trimmed) {
            let migrated = try SingBoxConfigMigrator.migrate(trimmed)
            let meta = SubscriptionMetadata.parse(headers: headers, body: trimmed)
            let name = resolveSubscriptionName(urlString: sourceURL, headers: headers, contentName: meta.title)
            return Result(
                name: name == "Subscription" ? meta.title : name,
                json: migrated,
                nodeCount: 0,
                metadata: meta
            )
        }

        // Happ / Remnawave XRAY_JSON: [{ remarks, outbounds: [{protocol:vless,...}], ...}, ...]
        if trimmed.hasPrefix("[") {
            var result = try buildConfig(fromXrayJSON: trimmed)
            let meta = SubscriptionMetadata.parse(headers: headers, body: trimmed)
            let resolvedName = resolveSubscriptionName(
                urlString: sourceURL,
                headers: headers,
                contentName: meta.title ?? result.name
            )
            result = Result(
                name: resolvedName == "Subscription" ? result.name : resolvedName,
                json: result.json,
                nodeCount: result.nodeCount,
                metadata: meta
            )
            return result
        }

        let links = decodeShareLinks(trimmed)
        if links.isEmpty {
            throw SubscriptionError.noSupportedLinks
        }

        if let blocked = unsupportedPlaceholderMessage(in: links) {
            throw SubscriptionError.panelRejected(blocked)
        }

        var result = try buildConfig(from: links)
        let meta = SubscriptionMetadata.parse(headers: headers, body: trimmed)
        let resolvedName = resolveSubscriptionName(
            urlString: sourceURL,
            headers: headers,
            contentName: meta.title ?? result.name
        )
        if resolvedName != "Subscription" {
            result = Result(name: resolvedName, json: result.json, nodeCount: result.nodeCount, metadata: meta)
        } else {
            result = Result(name: result.name, json: result.json, nodeCount: result.nodeCount, metadata: meta)
        }
        return result
    }

    public static func decodeShareLinks(_ content: String) -> [String] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let decoded = decodeBase64IfNeeded(trimmed) {
            return extractLinks(from: decoded)
        }
        return extractLinks(from: trimmed)
    }

    public static func buildConfig(from links: [String]) throws -> Result {
        var proxyTags: [String] = []
        var outbounds: [[String: Any]] = []
        var usedTags = Set<String>()
        var firstName: String?

        for (index, link) in links.enumerated() {
            let lower = link.lowercased()
            guard lower.hasPrefix("vless://") else {
                continue
            }
            // XHTTP requires VPN Direct Core (native transport). Skip on stock Libbox.
            if (lower.contains("type=xhttp") || lower.contains("type=splithttp")),
               !VPNDirectCoreCapabilities.current.supportsXHTTP
            {
                continue
            }
            do {
                let parsed = try VLESSConfigBuilder.parseOutbound(link, tag: "proxy-\(index + 1)")
                var outbound = parsed.outbound
                let tag = uniqueTag(from: parsed.name, fallback: "proxy-\(index + 1)", used: &usedTags)
                outbound["tag"] = tag
                proxyTags.append(tag)
                outbounds.append(outbound)
                if firstName == nil {
                    firstName = parsed.name
                }
            } catch {
                continue
            }
        }

        return try finalizeConfig(proxyTags: proxyTags, outbounds: outbounds, firstName: firstName)
    }

    /// Converts Remnawave / Happ `XRAY_JSON` array into a sing-box selector config.
    public static func buildConfig(fromXrayJSON content: String) throws -> Result {
        guard let data = content.data(using: .utf8),
              let profiles = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            throw SubscriptionError.xrayJSONUnsupported
        }

        var proxyTags: [String] = []
        var outbounds: [[String: Any]] = []
        var usedTags = Set<String>()
        var firstName: String?
        var seenServers = Set<String>()

        for (index, profile) in profiles.enumerated() {
            let remarks = ((profile["remarks"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = remarks.isEmpty ? "Server \(index + 1)" : remarks
            let xrayOutbounds = (profile["outbounds"] as? [[String: Any]]) ?? []

            let vlessOutbounds = xrayOutbounds.filter {
                ($0["protocol"] as? String)?.lowercased() == "vless"
            }

            // Remnawave "Автовыбор" packs every node into one profile with a balancer.
            // Prefer the separate named country profiles (same as Happ server list).
            let isAutoBalancer = displayName.localizedCaseInsensitiveContains("автовыбор")
                || displayName.localizedCaseInsensitiveContains("autoselect")
                || vlessOutbounds.count > 3
            if isAutoBalancer, profiles.count > 1 {
                continue
            }

            // One list row per profile: use primary `proxy` outbound (skip xhttp).
            let ordered = vlessOutbounds.sorted { lhs, rhs in
                let lt = (lhs["tag"] as? String) ?? ""
                let rt = (rhs["tag"] as? String) ?? ""
                if lt == "proxy" { return true }
                if rt == "proxy" { return false }
                return false
            }

            var converted: [String: Any]?
            var fingerprint = ""
            for xray in ordered {
                if let outbound = convertXrayVLESSOutbound(xray, fallbackTag: "proxy-\(index + 1)") {
                    let server = (outbound["server"] as? String) ?? ""
                    let port = outbound["server_port"] as? Int ?? 0
                    fingerprint = "\(server):\(port)"
                    converted = outbound
                    break
                }
            }
            guard var outbound = converted else { continue }

            if !fingerprint.isEmpty, !seenServers.insert(fingerprint).inserted {
                continue
            }

            let tag = uniqueTag(from: displayName, fallback: "proxy-\(index + 1)", used: &usedTags)
            outbound["tag"] = tag
            proxyTags.append(tag)
            outbounds.append(outbound)
            if firstName == nil {
                firstName = displayName
            }
        }

        return try finalizeConfig(proxyTags: proxyTags, outbounds: outbounds, firstName: firstName)
    }

    private static func finalizeConfig(
        proxyTags: [String],
        outbounds: [[String: Any]],
        firstName: String?
    ) throws -> Result {
        guard !proxyTags.isEmpty else {
            throw SubscriptionError.noSupportedLinks
        }

        let selectorOutbounds = ["auto"] + proxyTags
        let urlTest: [String: Any] = [
            "type": "urltest",
            "tag": "auto",
            "outbounds": proxyTags,
            "url": "https://www.gstatic.com/generate_204",
            "interval": "1m",
            "tolerance": 80,
            "idle_timeout": "30m",
        ]
        let selector: [String: Any] = [
            "type": "selector",
            "tag": "proxy",
            "outbounds": selectorOutbounds,
            "default": "auto",
        ]

        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
            ],
            "dns": [
                "servers": [
                    [
                        "type": "udp",
                        "tag": "dns-remote",
                        "server": "1.1.1.1",
                    ],
                    [
                        "type": "local",
                        "tag": "dns-local",
                    ],
                ],
                "final": "dns-remote",
                "strategy": "prefer_ipv4",
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": ["172.19.0.1/30"],
                    "mtu": 9000,
                    "auto_route": true,
                    "strict_route": true,
                    "stack": "gvisor",
                ],
            ],
            "outbounds": [selector, urlTest] + outbounds + [[
                "type": "direct",
                "tag": "direct",
            ]],
            "route": [
                "auto_detect_interface": true,
                "default_domain_resolver": [
                    "server": "dns-remote",
                    "strategy": "prefer_ipv4",
                ],
                "rules": [
                    [
                        "action": "sniff",
                    ],
                    [
                        "protocol": ["dns"],
                        "action": "hijack-dns",
                    ],
                    [
                        "ip_is_private": true,
                        "outbound": "direct",
                    ],
                ],
                "final": "proxy",
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SubscriptionError.serializationFailed
        }

        var error: NSError?
        LibboxCheckConfig(json, &error)
        if let error {
            throw error
        }

        let migrated = try SingBoxConfigMigrator.migrate(json)
        return Result(name: firstName, json: migrated, nodeCount: proxyTags.count, metadata: SubscriptionMetadata())
    }

    /// Maps a single Xray VLESS outbound object to sing-box. Returns nil for unsupported transports.
    private static func convertXrayVLESSOutbound(_ xray: [String: Any], fallbackTag: String) -> [String: Any]? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let network = ((stream["network"] as? String) ?? "tcp").lowercased()
        // Native XHTTP when Core supports it; otherwise skip (cannot safely map all modes).
        if (network == "xhttp" || network == "splithttp"), !VPNDirectCoreCapabilities.current.supportsXHTTP {
            return nil
        }

        let settings = (xray["settings"] as? [String: Any]) ?? [:]
        guard let vnext = (settings["vnext"] as? [[String: Any]])?.first else { return nil }
        let address = (vnext["address"] as? String) ?? ""
        guard !address.isEmpty else { return nil }
        let port = vnext["port"] as? Int ?? 443
        guard let user = (vnext["users"] as? [[String: Any]])?.first else { return nil }
        let uuid = (user["id"] as? String) ?? ""
        guard !uuid.isEmpty else { return nil }
        let flow = ((user["flow"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

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
        if let encryption = user["encryption"] as? String,
           !encryption.isEmpty,
           encryption.lowercased() != "none",
           VPNDirectCoreCapabilities.current.supportsVLESSEncryption
        {
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
            outbound["transport"] = transport
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
            if let extra = xhttp["extra"] as? String, !extra.isEmpty {
                transport["extra"] = extra
            } else if let extraObj = xhttp["extra"] as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: extraObj),
                      let extraJSON = String(data: data, encoding: .utf8)
            {
                transport["extra"] = extraJSON
            }
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

    private static func nameFromHeaders(_ headers: [String: String]) -> String? {
        let normalized = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        let keys = [
            "profile-title",
            "profile-update-title",
            "subscription-userinfo",
            "x-subscription-name",
            "content-disposition",
        ]
        for key in keys {
            guard let value = normalized[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                continue
            }
            if key == "content-disposition" {
                if let filename = filenameFromContentDisposition(value) {
                    return filename
                }
                continue
            }
            if key == "subscription-userinfo" {
                if let title = userInfoValue(named: "profile-title", in: value) ?? userInfoValue(named: "title", in: value) {
                    return SubscriptionMetadata.sanitizedTitle(title) ?? title
                }
                continue
            }
            return SubscriptionMetadata.sanitizedTitle(value) ?? value
        }
        return nil
    }

    private static func filenameFromContentDisposition(_ value: String) -> String? {
        let parts = value.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for part in parts {
            let lower = part.lowercased()
            if lower.hasPrefix("filename*=") {
                let raw = part.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                let encoded = raw.split(separator: "'", maxSplits: 2).last.map(String.init) ?? raw
                let decoded = encoded.removingPercentEncoding ?? encoded
                return cleanedSubscriptionTitle(decoded)
            }
            if lower.hasPrefix("filename=") {
                let raw = part.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                let unquoted = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return cleanedSubscriptionTitle(unquoted)
            }
        }
        return nil
    }

    private static func userInfoValue(named key: String, in header: String) -> String? {
        for part in header.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, pair[0].lowercased() == key.lowercased() else { continue }
            let decoded = pair[1].removingPercentEncoding ?? pair[1]
            let cleaned = cleanedSubscriptionTitle(decoded)
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }

    private static func domainLikePathComponent(in url: URL) -> String? {
        let host = url.host?.lowercased()
        for component in url.pathComponents where component != "/" {
            let cleaned = cleanedSubscriptionTitle(component)
            guard cleaned.contains("."), cleaned.count > 3 else { continue }
            if cleaned.lowercased() == host { continue }
            return cleaned
        }
        return nil
    }

    private static func cleanedSubscriptionTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"\.(txt|json|yaml|yml)$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isHostLikeName(_ value: String) -> Bool {
        looksLikeHost(value)
    }

    private static func looksLikeHost(_ value: String) -> Bool {
        let lower = value.lowercased()
        if lower.contains("://") { return true }
        let hostPattern = #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$"#
        return lower.range(of: hostPattern, options: .regularExpression) != nil
    }

    private static func looksLikeSingBoxJSON(_ content: String) -> Bool {
        content.hasPrefix("{") && content.contains("\"outbounds\"")
    }

    private static func extractLinks(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { line -> [String] in
                if line.contains("://") {
                    return line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                }
                return []
            }
            .filter { link in
                let lower = link.lowercased()
                return lower.hasPrefix("vless://")
                    || lower.hasPrefix("vmess://")
                    || lower.hasPrefix("ss://")
                    || lower.hasPrefix("trojan://")
                    || lower.hasPrefix("hysteria2://")
                    || lower.hasPrefix("hy2://")
            }
    }

    private static func decodeBase64IfNeeded(_ content: String) -> String? {
        let cleaned = content
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard cleaned.count >= 16, cleaned.range(of: #"^[A-Za-z0-9+/=_-]+$"#, options: .regularExpression) != nil else {
            return nil
        }

        let padded: String
        let remainder = cleaned.count % 4
        if remainder == 0 {
            padded = cleaned
        } else {
            padded = cleaned + String(repeating: "=", count: 4 - remainder)
        }

        let candidates: [Data?] = [
            Data(base64Encoded: padded),
            Data(base64Encoded: padded
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")),
        ]

        for data in candidates {
            guard let data, let decoded = String(data: data, encoding: .utf8) else { continue }
            if decoded.contains("://") {
                return decoded
            }
        }
        return nil
    }

    private static func unsupportedPlaceholderMessage(in links: [String]) -> String? {
        guard links.count == 1, let link = links.first else { return nil }
        let lower = link.lowercased()
        let isLoopbackStub = lower.contains("@127.0.0.1:1") || lower.contains("00000000-0000-0000-0000-000000000000")
        guard isLoopbackStub else { return nil }
        if let hashIndex = link.lastIndex(of: "#") {
            let fragment = String(link[link.index(after: hashIndex)...])
            let name = fragment.removingPercentEncoding ?? fragment
            if !name.isEmpty {
                return name
            }
        }
        return String(localized: "Subscription rejected this client")
    }

    private static func uniqueTag(from name: String, fallback: String, used: inout Set<String>) -> String {
        var base = name
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Za-z0-9._\-а-яА-ЯёЁ]"#, with: "", options: .regularExpression)
        if base.isEmpty {
            base = fallback
        }
        if base.count > 48 {
            base = String(base.prefix(48))
        }
        var tag = base
        var index = 2
        while used.contains(tag) || tag == "proxy" || tag == "direct" {
            tag = "\(base)-\(index)"
            index += 1
        }
        used.insert(tag)
        return tag
    }

    public enum SubscriptionError: LocalizedError {
        case empty
        case noSupportedLinks
        case serializationFailed
        case panelRejected(String)
        case xrayJSONUnsupported

        public var errorDescription: String? {
            switch self {
            case .empty:
                return String(localized: "Subscription is empty")
            case .noSupportedLinks:
                return String(localized: "No supported vless:// links found in subscription")
            case .serializationFailed:
                return String(localized: "Failed to serialize subscription configuration")
            case let .panelRejected(message):
                return message
            case .xrayJSONUnsupported:
                return String(localized: "Unsupported XRAY JSON subscription format")
            }
        }
    }
}
