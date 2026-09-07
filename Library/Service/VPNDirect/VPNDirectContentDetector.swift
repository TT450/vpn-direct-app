import Foundation

/// Content kinds detected from raw subscription / import payloads.
public enum VPNDirectContentKind: String, Equatable, Sendable {
    case singBoxJSON
    case xrayJSON
    case clashYAML
    case wireGuardConf
    case mieruJSON
    case uriList
    case base64URIList
    case unknown
}

/// Ordered content detector: encoding first, then type. Does **not** line-trim before YAML detection.
public enum VPNDirectContentDetector {
    public struct Detection: Equatable, Sendable {
        public var kind: VPNDirectContentKind
        public var text: String
        public var wasBase64Decoded: Bool

        public init(kind: VPNDirectContentKind, text: String, wasBase64Decoded: Bool = false) {
            self.kind = kind
            self.text = text
            self.wasBase64Decoded = wasBase64Decoded
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
        let leading = strippedBOM.drop(while: { $0.isNewline || $0 == " " || $0 == "\t" })
        let preview = String(leading.prefix(4096))

        if looksLikeSingBoxJSON(preview) {
            return Detection(kind: .singBoxJSON, text: strippedBOM)
        }
        if looksLikeXrayJSON(preview) {
            return Detection(kind: .xrayJSON, text: strippedBOM)
        }
        if looksLikeMieruJSON(preview) {
            return Detection(kind: .mieruJSON, text: strippedBOM)
        }
        if looksLikeClashYAML(strippedBOM) {
            return Detection(kind: .clashYAML, text: strippedBOM)
        }
        if looksLikeWireGuardConf(strippedBOM) {
            return Detection(kind: .wireGuardConf, text: strippedBOM)
        }

        let compact = strippedBOM.trimmingCharacters(in: .whitespacesAndNewlines)
        if let decoded = decodeBase64Payload(compact), containsShareScheme(decoded) {
            // Re-detect decoded payload (may itself be YAML/JSON).
            let nested = detect(text: decoded)
            if nested.kind != .unknown, nested.kind != .uriList, nested.kind != .base64URIList {
                return Detection(kind: nested.kind, text: nested.text, wasBase64Decoded: true)
            }
            return Detection(kind: .base64URIList, text: decoded, wasBase64Decoded: true)
        }
        if containsShareScheme(strippedBOM) {
            return Detection(kind: .uriList, text: strippedBOM)
        }
        return Detection(kind: .unknown, text: strippedBOM)
    }

    private static func looksLikeSingBoxJSON(_ preview: String) -> Bool {
        let t = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("{") && (t.contains("\"outbounds\"") || t.contains("\"inbounds\""))
    }

    private static func looksLikeXrayJSON(_ preview: String) -> Bool {
        let t = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("[") else { return false }
        return t.contains("\"outbounds\"") || t.contains("\"protocol\"") || t.contains("\"remarks\"")
    }

    private static func looksLikeMieruJSON(_ preview: String) -> Bool {
        let t = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("{") else { return false }
        let lower = t.lowercased()
        return lower.contains("\"profiles\"") && (lower.contains("\"mieru\"") || lower.contains("\"userdataencryption\"") || lower.contains("\"mtu\""))
            || lower.contains("\"activeprofile\"")
            || (lower.contains("\"serverport\"") && lower.contains("\"username\"") && lower.contains("\"password\""))
    }

    private static func looksLikeClashYAML(_ text: String) -> Bool {
        // Do not trim each line — only scan for Clash markers.
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
        // Intentionally omit ssr:// — no parser; treating it as a share scheme caused false uriList hits.
        let schemes = [
            "vless://", "vmess://", "trojan://", "ss://",
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
            if !decoded.isEmpty { return decoded }
        }
        return nil
    }
}
