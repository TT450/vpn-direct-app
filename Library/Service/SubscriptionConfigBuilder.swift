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
        /// Partial-import diagnostics (URI lists, etc.). Never silent when parsed < total.
        public let diagnostics: VPNDirectParseDiagnostics?
        public let warnings: [String]

        public init(
            name: String?,
            json: String,
            nodeCount: Int,
            metadata: SubscriptionMetadata,
            diagnostics: VPNDirectParseDiagnostics? = nil,
            warnings: [String] = []
        ) {
            self.name = name
            self.json = json
            self.nodeCount = nodeCount
            self.metadata = metadata
            self.diagnostics = diagnostics
            self.warnings = warnings
        }

        /// User-facing summary when some links failed but others imported.
        public var partialImportSummary: String? {
            guard let d = diagnostics, d.parsed > 0, (d.unsupported + d.malformed) > 0 else {
                return nil
            }
            let failed = d.unsupported + d.malformed
            var parts = [
                "Imported \(d.parsed) of \(d.total). \(failed) configuration(s) were not supported or malformed.",
            ]
            if !d.unsupportedComponents.isEmpty {
                parts.append("Components: \(d.unsupportedComponents.prefix(8).joined(separator: ", "))")
            }
            return parts.joined(separator: " ")
        }
    }

    public static func isHTTPURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    /// True when content contains at least one supported share-link scheme (vmess/trojan/…, not only vless).
    public static func isShareLinkContent(_ raw: String) -> Bool {
        !decodeShareLinks(raw).isEmpty
    }

    public static func suggestedName(forShareContent raw: String) -> String {
        let links = decodeShareLinks(raw)
        let parsed = VPNDirectParserRegistry.parseShareLinks(links)
        if let name = parsed.nodes.first?.name.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return "Share link"
    }

    private static let shareLinkSchemePrefixes: [String] = [
        "vless://", "vmess://", "ss://", "ssr://", "trojan://",
        "hysteria://", "hysteria2://", "hy2://", "tuic://", "anytls://",
        "wireguard://", "wg://", "awg://",
        "socks://", "socks5://", "socks4://", "ssh://",
        "http-proxy://", "https-proxy://", "shadowtls://",
        "naive://", "naive+https://", "naive+quic://",
    ]

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

    public static func fetchAndNormalize(
        url: String,
        cachedETag: String? = nil,
        cachedLastModified: String? = nil
    ) async throws -> Result {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var lastError: Error = SubscriptionError.empty
        // Happ-first (Remnawave / Happ panels need HWID for XRAY_JSON); generic UA is last fallback.
        precondition(SubscriptionClientIdentity.userAgents.first == SubscriptionClientIdentity.primaryUserAgent)
        precondition(SubscriptionClientIdentity.userAgents.contains(SubscriptionClientIdentity.genericUserAgent))

        for agent in SubscriptionClientIdentity.userAgents {
            do {
                let response = try await SubscriptionHTTP.fetch(
                    url: trimmedURL,
                    userAgent: agent,
                    cachedETag: cachedETag,
                    cachedLastModified: cachedLastModified
                )
                do {
                    return try normalizeRemoteContent(response.body, sourceURL: trimmedURL, headers: response.headers)
                } catch {
                    lastError = error
                    // Panel stub / wrong format for this UA → try next identity.
                    if case SubscriptionError.panelRejected = error {
                        continue
                    }
                    if case SubscriptionError.noSupportedLinks = error {
                        continue
                    }
                    if case SubscriptionError.empty = error {
                        continue
                    }
                    // HTML browser page is not usable as a profile body.
                    let lowered = response.body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if lowered.hasPrefix("<!doctype") || lowered.hasPrefix("<html") {
                        continue
                    }
                    // Happ (or current UA) returned something we cannot parse — try fallback UA.
                    continue
                }
            } catch is SubscriptionHTTP.ConditionalNotModified {
                throw SubscriptionHTTP.ConditionalNotModified()
            } catch let httpError as SubscriptionHTTP.HTTPResponseError {
                let classified = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
                    statusCode: httpError.statusCode,
                    headers: httpError.headers,
                    body: httpError.body,
                    userAgent: httpError.userAgent
                )
                // Panel identity errors / blocks: do not rotate UA blindly — surface typed failure.
                switch classified.category {
                case .deviceLimitReached, .hwidRejected, .subscriptionExpired,
                     .subscriptionDisabled, .panelBlocked, .unavailableForLegalReasons,
                     .notFound, .unauthorized:
                    throw SubscriptionError.panelRejected(classified.userSafeMessage)
                case .browserPayload:
                    // Try next UA — Happ vs generic can change response type.
                    lastError = SubscriptionError.panelRejected(classified.userSafeMessage)
                    continue
                case .socketDrop:
                    lastError = SubscriptionError.panelRejected(classified.userSafeMessage)
                    continue
                case .httpError, .networkError, .malformedResponse, .unsupportedFormat, .ok:
                    lastError = httpError
                    continue
                }
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    /// Accepts raw remote body: sing-box JSON, Xray JSON, Clash YAML, WG/AWG conf, Mieru JSON, URI lists.
    public static func normalizeRemoteContent(
        _ content: String,
        sourceURL: String = "",
        headers: [String: String] = [:]
    ) throws -> Result {
        let detection = VPNDirectContentDetector.detect(text: content)
        guard detection.kind != .unknown, !detection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SubscriptionError.empty
        }

        switch detection.kind {
        case .recognizedUnsupported:
            let id = detection.unsupportedProtocolID ?? "unknown"
            throw SubscriptionError.unsupportedFeatures(["recognized_unsupported.\(id)"])

        case .singBoxJSON:
            let migrated = try SingBoxConfigMigrator.migrate(detection.text)
            let validated = try VPNDirectConfigValidator.validateSingBoxJSON(migrated)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            let name = resolveSubscriptionName(urlString: sourceURL, headers: headers, contentName: meta.title)
            return Result(
                name: name == "Subscription" ? meta.title : name,
                json: validated.json,
                nodeCount: 0,
                metadata: meta
            )

        case .xrayJSON:
            var result = try buildConfig(fromXrayJSON: detection.text)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            let resolvedName = resolveSubscriptionName(
                urlString: sourceURL,
                headers: headers,
                contentName: meta.title ?? result.name
            )
            return Result(
                name: resolvedName == "Subscription" ? result.name : resolvedName,
                json: result.json,
                nodeCount: result.nodeCount,
                metadata: meta
            )

        case .clashYAML:
            let subscription = try ClashYAMLAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            let resolved = resolveSubscriptionName(urlString: sourceURL, headers: headers, contentName: meta.title ?? graph.firstName)
            return Result(name: resolved, json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .wireGuardConf:
            let subscription = try WireGuardConfAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            return Result(name: graph.firstName ?? "WireGuard", json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .mieruJSON:
            let subscription = try MieruConfigAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            return Result(name: graph.firstName ?? "Mieru", json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .openVPNConfig:
            let subscription = try OpenVPNConfigAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            return Result(name: graph.firstName ?? "OpenVPN", json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .openConnectConfig:
            let subscription = try OpenConnectConfigAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            return Result(name: graph.firstName ?? "OpenConnect", json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .tailscaleJSON:
            let subscription = try TailscaleConfigAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            return Result(name: graph.firstName ?? "Tailscale", json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .masqueConnectUDPJSON:
            let subscription = try MasqueConnectUDPAdapter.parse(detection.text)
            let graph = try SingBoxGraphBuilder.build(from: subscription)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            return Result(name: graph.firstName ?? "MASQUE CONNECT-UDP", json: graph.json, nodeCount: graph.leafCount, metadata: meta)

        case .uriList, .base64URIList:
            let links = extractLinks(from: detection.text)
            if links.isEmpty {
                throw SubscriptionError.noSupportedLinks
            }
            if let blocked = unsupportedPlaceholderMessage(in: links) {
                throw SubscriptionError.panelRejected(blocked)
            }
            var result = try buildConfig(from: links)
            let meta = SubscriptionMetadata.parse(headers: headers, body: detection.text)
            let resolvedName = resolveSubscriptionName(
                urlString: sourceURL,
                headers: headers,
                contentName: meta.title ?? result.name
            )
            return Result(
                name: resolvedName == "Subscription" ? result.name : resolvedName,
                json: result.json,
                nodeCount: result.nodeCount,
                metadata: meta
            )

        case .unknown:
            throw SubscriptionError.noSupportedLinks
        }
    }

    public static func decodeShareLinks(_ content: String) -> [String] {
        let trimmed = VPNDirectContentDetector.normalizeImportMarkup(content)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let decoded = decodeBase64IfNeeded(trimmed) {
            return extractLinks(from: decoded)
        }
        return extractLinks(from: trimmed)
    }

    public static func buildConfig(from links: [String]) throws -> Result {
        let parsed = VPNDirectParserRegistry.parseShareLinks(links)
        if parsed.nodes.isEmpty {
            if !parsed.diagnostics.unsupportedComponents.isEmpty {
                throw SubscriptionError.unsupportedFeatures(parsed.diagnostics.unsupportedComponents)
            }
            throw SubscriptionError.noSupportedLinks
        }
        let graph = try SingBoxGraphBuilder.build(fromShareNodes: parsed.nodes)
        var warnings: [String] = []
        if let summary = Result(
            name: nil,
            json: "",
            nodeCount: 0,
            metadata: SubscriptionMetadata(),
            diagnostics: parsed.diagnostics
        ).partialImportSummary {
            warnings.append(summary)
        }
        return Result(
            name: graph.firstName,
            json: graph.json,
            nodeCount: graph.leafCount,
            metadata: SubscriptionMetadata(),
            diagnostics: parsed.diagnostics,
            warnings: warnings
        )
    }

    /// Converts Remnawave / Happ `XRAY_JSON` array into a sing-box selector config.
    public static func buildConfig(fromXrayJSON content: String) throws -> Result {
        let subscription = try XrayJSONAdapter.parse(content)
        let graph = try SingBoxGraphBuilder.build(from: subscription)
        return Result(
            name: graph.firstName,
            json: graph.json,
            nodeCount: graph.leafCount,
            metadata: SubscriptionMetadata()
        )
    }

    private static func uniqueTag(from name: String, fallback: String, used: inout Set<String>) -> String {
        VPNDirectTagFactory.uniqueTag(from: name, fallback: fallback, used: &used)
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
            .filter { !$0.isEmpty }
            .flatMap { line -> [String] in
                let lower = line.lowercased()
                // Fragments often contain spaces / emoji (`#CA 🇨🇦 | @user`). Never whitespace-split
                // a line that already starts with a known share scheme.
                if shareLinkSchemePrefixes.contains(where: { lower.hasPrefix($0) }) {
                    return [line]
                }
                if line.contains("://") {
                    return line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                }
                return []
            }
            .filter { link in
                let lower = link.lowercased()
                return shareLinkSchemePrefixes.contains(where: { lower.hasPrefix($0) })
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
        guard EndpointValidator.isPanelStubLink(link) else { return nil }
        if let hashIndex = link.lastIndex(of: "#") {
            let fragment = String(link[link.index(after: hashIndex)...])
            let name = fragment.removingPercentEncoding ?? fragment
            if !name.isEmpty {
                return name
            }
        }
        return String(localized: "Subscription rejected this client")
    }

    public enum SubscriptionError: LocalizedError {
        case empty
        case noSupportedLinks
        case unsupportedFeatures([String])
        case serializationFailed
        case panelRejected(String)
        case xrayJSONUnsupported

        public var errorDescription: String? {
            switch self {
            case .empty:
                return String(localized: "Subscription is empty")
            case .noSupportedLinks:
                return String(localized: "No supported share links or subscription format found")
            case let .unsupportedFeatures(components):
                let joined = components.joined(separator: ", ")
                return String(localized: "Subscription requires unsupported features: \(joined)")
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
