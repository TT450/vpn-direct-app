import Foundation

/// Content kinds detected from raw subscription / import payloads.
public enum VPNDirectContentKind: String, Equatable, Sendable {
    case singBoxJSON
    case xrayJSON
    case clashYAML
    case wireGuardConf
    case mieruJSON
    case openVPNConfig
    case openConnectConfig
    case tailscaleJSON
    case masqueConnectUDPJSON
    case uriList
    case base64URIList
    /// Recognized protocol/format that VPN Direct intentionally does not import.
    case recognizedUnsupported
    case unknown
}

/// Ordered content detector: structural JSON first, then YAML/conf/URI.
public enum VPNDirectContentDetector {
    public struct Detection: Equatable, Sendable {
        public var kind: VPNDirectContentKind
        public var text: String
        public var wasBase64Decoded: Bool
        /// When kind == .recognizedUnsupported.
        public var unsupportedProtocolID: String?

        public init(
            kind: VPNDirectContentKind,
            text: String,
            wasBase64Decoded: Bool = false,
            unsupportedProtocolID: String? = nil
        ) {
            self.kind = kind
            self.text = text
            self.wasBase64Decoded = wasBase64Decoded
            self.unsupportedProtocolID = unsupportedProtocolID
        }
    }

    /// Detect from UTF-8 bytes without destructive per-line trimming (preserves YAML indentation).
    public static func detect(data: Data) -> Detection {
        if let text = String(data: data, encoding: .utf8) {
            return detect(text: text)
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return detect(text: text)
        }
        return Detection(kind: .unknown, text: "")
    }

    public static func detect(text: String) -> Detection {
        let strippedBOM = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let normalized = normalizeImportMarkup(strippedBOM)

        // Strip leading subscription comment / Hiddify-style metadata lines before structural JSON.
        let (cleanedBody, _) = stripLeadingMetadataComments(from: normalized)
        let leading = cleanedBody.drop(while: { $0.isNewline || $0 == " " || $0 == "\t" })
        let bodyForJSON = String(leading)

        // Share-link lists (including mixed ssr:// + supported schemes).
        let compact = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        if let decoded = decodeBase64Payload(compact) {
            let nested = detect(text: decoded)
            if nested.kind != .unknown, nested.kind != .uriList, nested.kind != .base64URIList {
                return Detection(
                    kind: nested.kind,
                    text: nested.text,
                    wasBase64Decoded: true,
                    unsupportedProtocolID: nested.unsupportedProtocolID
                )
            }
            if containsShareScheme(decoded) {
                return Detection(kind: .base64URIList, text: decoded, wasBase64Decoded: true)
            }
        }
        if containsShareScheme(normalized) {
            return Detection(kind: .uriList, text: normalized)
        }

        if looksLikeOpenVPN(normalized) {
            return Detection(kind: .openVPNConfig, text: normalized)
        }
        if looksLikeOpenConnect(normalized) {
            return Detection(kind: .openConnectConfig, text: normalized)
        }

        if let kind = classifyJSON(bodyForJSON) {
            let payload = cleanedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? normalized
                : cleanedBody
            return Detection(kind: kind, text: payload)
        }

        if looksLikeClashYAML(normalized) {
            return Detection(kind: .clashYAML, text: normalized)
        }
        if looksLikeWireGuardConf(normalized) {
            return Detection(kind: .wireGuardConf, text: normalized)
        }

        if let unsupported = recognizeUnsupported(normalized) {
            return Detection(
                kind: .recognizedUnsupported,
                text: normalized,
                unsupportedProtocolID: unsupported
            )
        }

        return Detection(kind: .unknown, text: normalized)
    }

    /// Telegram / web pastes often glue links with HTML breaks.
    public static func normalizeImportMarkup(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
    }

    // MARK: - Structural JSON

    private static func classifyJSON(_ text: String) -> VPNDirectContentKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data)
        else { return nil }

        if let arr = obj as? [Any] {
            return classifyXrayArray(arr) ? .xrayJSON : nil
        }
        guard let dict = obj as? [String: Any] else { return nil }

        if looksLikeMieruObject(dict) {
            return .mieruJSON
        }
        if looksLikeTailscaleObject(dict) {
            return .tailscaleJSON
        }
        if looksLikeMasqueConnectUDPObject(dict) {
            return .masqueConnectUDPJSON
        }
        if looksLikeOpenConnectObject(dict) {
            return .openConnectConfig
        }
        if looksLikeOpenVPNObject(dict) {
            return .openVPNConfig
        }
        if looksLikeSingBoxObject(dict) {
            return .singBoxJSON
        }
        if looksLikeXrayObject(dict) {
            return .xrayJSON
        }
        // Top-level object with outbounds array (3x-ui / Xray profile object).
        if let outs = dict["outbounds"] as? [Any], !outs.isEmpty {
            if outs.contains(where: { ($0 as? [String: Any])?["protocol"] != nil }) {
                return .xrayJSON
            }
            if outs.contains(where: { ($0 as? [String: Any])?["type"] != nil }) {
                // Could be sing-box without inbounds — prefer sing-box if type keys dominate.
                let typed = outs.compactMap { $0 as? [String: Any] }
                if typed.contains(where: { ($0["type"] as? String) != nil }) {
                    return .singBoxJSON
                }
            }
        }
        return nil
    }

    private static func looksLikeSingBoxObject(_ dict: [String: Any]) -> Bool {
        let hasOutbounds = dict["outbounds"] is [Any]
        let hasInbounds = dict["inbounds"] is [Any]
        let hasEndpoints = dict["endpoints"] is [Any]
        let hasRoute = dict["route"] != nil
        guard hasOutbounds || hasInbounds || hasEndpoints else { return false }
        // Prefer sing-box when typed outbounds/endpoints exist.
        if hasEndpoints { return true }
        if let outs = dict["outbounds"] as? [[String: Any]],
           outs.contains(where: { $0["type"] is String })
        {
            return true
        }
        if hasInbounds, hasRoute { return true }
        if hasInbounds, hasOutbounds { return true }
        return false
    }

    private static func looksLikeXrayObject(_ dict: [String: Any]) -> Bool {
        if dict["remarks"] is String { return true }
        if let outs = dict["outbounds"] as? [[String: Any]],
           outs.contains(where: { $0["protocol"] is String })
        {
            return true
        }
        if dict["protocol"] is String { return true }
        return false
    }

    private static func classifyXrayArray(_ arr: [Any]) -> Bool {
        for item in arr {
            guard let dict = item as? [String: Any] else { continue }
            if dict["remarks"] != nil || dict["protocol"] != nil { return true }
            if let outs = dict["outbounds"] as? [[String: Any]],
               outs.contains(where: { $0["protocol"] != nil || $0["type"] != nil })
            {
                return true
            }
        }
        return false
    }

    private static func looksLikeMieruObject(_ dict: [String: Any]) -> Bool {
        if dict["profiles"] is [Any] { return true }
        if dict["activeProfile"] != nil { return true }
        if dict["userName"] != nil || dict["username"] != nil {
            if dict["serverPort"] != nil || dict["serverPorts"] != nil || dict["serverAddress"] != nil {
                return true
            }
        }
        return false
    }

    /// Leading `#` / `//` metadata lines (Hiddify / panel comments) before `{`/`[`.
    private static func stripLeadingMetadataComments(from text: String) -> (String, Bool) {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var removed = false
        while let first = lines.first {
            let t = first.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("//") {
                lines.removeFirst()
                removed = true
                continue
            }
            break
        }
        return (lines.joined(separator: "\n"), removed)
    }

    private static func recognizeUnsupported(_ text: String) -> String? {
        // Reserved for formats that remain intentionally rejected.
        _ = text
        return nil
    }

    private static func looksLikeOpenVPN(_ text: String) -> Bool {
        let lower = text.lowercased()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return false }
        if trimmed.lowercased().hasPrefix("client"), lower.contains("dev"), lower.contains("proto") {
            return true
        }
        if lower.contains("remote "), lower.contains("proto ") {
            if lower.contains("-----begin certificate-----") || lower.contains("<ca>") || lower.contains("tls-client") {
                return true
            }
        }
        return false
    }

    private static func looksLikeOpenConnect(_ text: String) -> Bool {
        let lower = text.lowercased()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") { return false }
        if lower.contains("<openconnect") { return true }
        if lower.contains("anyconnect"), lower.contains("servercert") { return true }
        if lower.contains("<serverlist>"), lower.contains("<host>") { return true }
        return false
    }

    private static func looksLikeTailscaleObject(_ dict: [String: Any]) -> Bool {
        if let type = dict["type"] as? String, type.lowercased() == "tailscale" { return true }
        if let endpoints = dict["endpoints"] as? [[String: Any]],
           endpoints.contains(where: { ($0["type"] as? String)?.lowercased() == "tailscale" }),
           dict["outbounds"] == nil, dict["inbounds"] == nil
        {
            return true
        }
        if dict["auth_key"] != nil, dict["control_url"] != nil, dict["outbounds"] == nil {
            return true
        }
        return false
    }

    private static func looksLikeMasqueConnectUDPObject(_ dict: [String: Any]) -> Bool {
        if let type = dict["type"] as? String {
            let t = type.lowercased()
            if t == "masque-connect-udp" { return true }
            if t == "masque" {
                let mode = (dict["mode"] as? String)?.lowercased() ?? ""
                let proto = (dict["protocol"] as? String)?.lowercased() ?? ""
                return mode == "connect-udp" || proto == "connect-udp"
            }
        }
        if let outs = dict["outbounds"] as? [[String: Any]],
           outs.contains(where: { looksLikeMasqueConnectUDPObject($0) }),
           dict["inbounds"] == nil
        {
            return true
        }
        return false
    }

    private static func looksLikeOpenConnectObject(_ dict: [String: Any]) -> Bool {
        (dict["type"] as? String)?.lowercased() == "openconnect"
    }

    private static func looksLikeOpenVPNObject(_ dict: [String: Any]) -> Bool {
        (dict["type"] as? String)?.lowercased() == "openvpn-client"
    }

    private static func looksLikeClashYAML(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("\nproxies:") || lower.hasPrefix("proxies:") { return true }
        if lower.contains("proxy-groups:") { return true }
        if lower.contains("mixed-port:") || lower.contains("\nport:") {
            return lower.contains("proxies:")
        }
        return false
    }

    private static func looksLikeWireGuardConf(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("[interface]") && lower.contains("[peer]") && lower.contains("privatekey")
    }

    private static func containsShareScheme(_ text: String) -> Bool {
        let lower = text.lowercased()
        let schemes = [
            "vless://", "vmess://", "trojan://", "ss://", "ssr://",
            "hysteria://", "hysteria2://", "hy2://", "tuic://", "anytls://",
            "wireguard://", "wg://", "awg://", "socks://", "socks5://", "socks4://",
            "ssh://", "shadowtls://",
            "naive://", "naive+https://", "naive+quic://",
            "http-proxy://", "https-proxy://",
        ]
        return schemes.contains { lower.contains($0) }
    }

    private static func decodeBase64Payload(_ content: String) -> String? {
        let cleaned = content
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard cleaned.count >= 16, cleaned.range(of: #"^[A-Za-z0-9+/=_-]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        // Cap decoded input size to avoid zip-bomb style base64.
        guard cleaned.count <= 48 * 1024 * 1024 else { return nil }
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
            guard let data, data.count <= 32 * 1024 * 1024,
                  let decoded = String(data: data, encoding: .utf8)
            else { continue }
            if !decoded.isEmpty { return decoded }
        }
        return nil
    }
}
