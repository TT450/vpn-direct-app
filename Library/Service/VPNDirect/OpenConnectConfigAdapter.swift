import Foundation

/// Parses OpenConnect / AnyConnect-ish text or minimal XML into a sing-box `openconnect` endpoint.
public enum OpenConnectConfigAdapter {
    public static func parse(_ text: String) throws -> NormalizedSubscription {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            return try parseJSON(trimmed)
        }
        let fields = parseLoose(trimmed)
        guard let server = fields["server"], !server.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "openconnect", detail: "Missing server")
        }
        var endpoint: [String: Any] = [
            "type": "openconnect",
            "tag": "openconnect",
            "server": server,
        ]
        if let flavor = fields["flavor"] { endpoint["flavor"] = flavor }
        if let user = fields["username"] ?? fields["user"] { endpoint["username"] = user }
        if let pass = fields["password"] ?? fields["pass"] { endpoint["password"] = pass }
        if let group = fields["auth_group"] ?? fields["authgroup"] ?? fields["group"] {
            endpoint["auth_group"] = group
        }
        if let cookie = fields["cookie"] { endpoint["cookie"] = cookie }
        if let ca = fields["servercert"] ?? fields["certificate_authority"] {
            endpoint["tls"] = [
                "certificate_authority": [normalizePEM(ca)],
            ]
        }

        let hostPort = splitHostPort(server)
        let node = NormalizedNode(
            name: "OpenConnect",
            protocolID: .openconnect,
            server: hostPort.host,
            port: hostPort.port,
            attributes: fields,
            outbound: endpoint
        )
        return NormalizedSubscription(
            name: "OpenConnect",
            locations: [
                NormalizedLocation(
                    id: "openconnect",
                    name: "OpenConnect",
                    kind: .server,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }

    private static func parseJSON(_ text: String) throws -> NormalizedSubscription {
        guard let data = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "openconnect", detail: "Invalid JSON")
        }
        var endpoint = obj
        if (endpoint["type"] as? String)?.lowercased() != "openconnect" {
            endpoint["type"] = "openconnect"
        }
        if endpoint["tag"] == nil { endpoint["tag"] = "openconnect" }
        guard let server = endpoint["server"] as? String, !server.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "openconnect", detail: "Missing server")
        }
        let hostPort = splitHostPort(server)
        let node = NormalizedNode(
            name: (endpoint["tag"] as? String) ?? "OpenConnect",
            protocolID: .openconnect,
            server: hostPort.host,
            port: hostPort.port,
            outbound: endpoint
        )
        return NormalizedSubscription(
            name: "OpenConnect",
            locations: [
                NormalizedLocation(
                    id: "openconnect",
                    name: "OpenConnect",
                    kind: .server,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }

    private static func parseLoose(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        let lower = text.lowercased()

        if let match = firstMatch(#"(?i)https?://[^\s\"'<>]+"#, in: text) {
            fields["server"] = match
        } else if let match = firstMatch(#"(?i)Host\s*=\s*([^\s;]+)"#, in: text) {
            fields["server"] = match
        } else if let match = firstMatch(#"(?i)<ServerList>.*?<Host>([^<]+)</Host>"#, in: text) {
            fields["server"] = match
        }

        if let user = firstMatch(#"(?i)(?:username|user)\s*[=:]\s*([^\s]+)"#, in: text) {
            fields["username"] = user
        }
        if let pass = firstMatch(#"(?i)(?:password|pass)\s*[=:]\s*([^\s]+)"#, in: text) {
            fields["password"] = pass
        }
        if let group = firstMatch(#"(?i)(?:auth.?group|group)\s*[=:]\s*([^\s]+)"#, in: text) {
            fields["auth_group"] = group
        }
        if lower.contains("anyconnect") { fields["flavor"] = "anyconnect" }
        if lower.contains("fortinet") { fields["flavor"] = "fortinet" }
        if lower.contains("globalprotect") || lower.contains("\"gp\"") { fields["flavor"] = "gp" }
        if let cert = firstMatch(#"(?i)servercert\s*[=:]\s*([^\s]+)"#, in: text) {
            fields["servercert"] = cert
        }
        return fields
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        let idx = match.numberOfRanges > 1 ? 1 : 0
        guard let swiftRange = Range(match.range(at: idx), in: text) else { return nil }
        return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitHostPort(_ server: String) -> (host: String, port: Int) {
        if let url = URL(string: server), let host = url.host {
            return (host, url.port ?? 443)
        }
        if server.contains(":"), !server.contains("://") {
            let parts = server.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count >= 2, let port = Int(parts.last!) {
                return (parts.dropLast().joined(separator: ":"), port)
            }
        }
        return (server, 443)
    }

    private static func normalizePEM(_ value: String) -> String {
        if value.contains("BEGIN CERTIFICATE") { return value }
        return value
    }
}
