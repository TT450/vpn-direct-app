import Foundation

/// Parses classic OpenVPN client `.ovpn` / `.conf` into a sing-box `openvpn-client` endpoint.
public enum OpenVPNConfigAdapter {
    public static func parse(_ text: String) throws -> NormalizedSubscription {
        let parsed = try parseDirectives(text)
        guard let remote = parsed.remotes.first else {
            throw VPNDirectCoreError.malformedConfig(component: "openvpn", detail: "Missing remote")
        }
        var endpoint: [String: Any] = [
            "type": "openvpn-client",
            "tag": "openvpn-client",
            "server": remote.host,
            "server_port": remote.port,
            "network": parsed.proto,
            "mode": parsed.staticKey == nil ? "tls" : "static_key",
        ]
        if parsed.remotes.count > 1 {
            endpoint["servers"] = parsed.remotes.map { remote -> [String: Any] in
                [
                    "server": remote.host,
                    "server_port": remote.port,
                    "network": remote.proto ?? parsed.proto,
                ]
            }
        }
        if let user = parsed.username { endpoint["username"] = user }
        if let pass = parsed.password { endpoint["password"] = pass }
        if let cipher = parsed.cipher { endpoint["cipher"] = cipher }
        if let auth = parsed.auth { endpoint["auth"] = auth }
        if let topology = parsed.topology { endpoint["topology"] = topology }
        if !parsed.addresses.isEmpty { endpoint["address"] = parsed.addresses }
        if let peer = parsed.peerAddress { endpoint["peer_address"] = peer }
        if let key = parsed.staticKey {
            endpoint["static_key"] = [key]
            endpoint["key_direction"] = parsed.keyDirection ?? "client"
        }
        if parsed.ca != nil || parsed.cert != nil || parsed.key != nil || parsed.tlsAuth != nil || parsed.tlsCrypt != nil {
            var tls: [String: Any] = [:]
            if let ca = parsed.ca { tls["certificate"] = [ca] }
            if let cert = parsed.cert { tls["client_certificate"] = [cert] }
            if let key = parsed.key { tls["client_key"] = [key] }
            if let wrap = parsed.tlsCrypt {
                tls["control_wrap"] = [
                    "type": "tls-crypt",
                    "key": [wrap],
                ]
            } else if let wrap = parsed.tlsAuth {
                var control: [String: Any] = [
                    "type": "tls-auth",
                    "key": [wrap],
                ]
                if let direction = parsed.keyDirection {
                    control["direction"] = direction
                }
                tls["control_wrap"] = control
            }
            endpoint["tls"] = tls
        }
        if parsed.remoteRandom { endpoint["remote_random"] = true }
        if parsed.redirectGateway { endpoint["redirect_gateway"] = true }

        let node = NormalizedNode(
            name: "OpenVPN",
            protocolID: .openvpn,
            server: remote.host,
            port: remote.port,
            attributes: [
                "network": parsed.proto,
                "mode": (endpoint["mode"] as? String) ?? "tls",
            ],
            outbound: endpoint
        )
        return NormalizedSubscription(
            name: "OpenVPN",
            locations: [
                NormalizedLocation(
                    id: "openvpn",
                    name: "OpenVPN",
                    kind: .server,
                    strategy: .single,
                    endpoints: [node]
                ),
            ]
        )
    }

    // MARK: - Directive parse

    private struct Remote {
        var host: String
        var port: Int
        var proto: String?
    }

    private struct Parsed {
        var remotes: [Remote] = []
        var proto: String = "udp"
        var username: String?
        var password: String?
        var cipher: String?
        var auth: String?
        var topology: String?
        var addresses: [String] = []
        var peerAddress: String?
        var staticKey: String?
        var keyDirection: String?
        var ca: String?
        var cert: String?
        var key: String?
        var tlsAuth: String?
        var tlsCrypt: String?
        var remoteRandom = false
        var redirectGateway = false
    }

    private static func parseDirectives(_ text: String) throws -> Parsed {
        var parsed = Parsed()
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            i += 1
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") { continue }

            if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
                let tag = String(trimmed.dropFirst().dropLast()).lowercased()
                var body: [String] = []
                while i < lines.count {
                    let line = lines[i]
                    i += 1
                    if line.trimmingCharacters(in: .whitespaces).lowercased() == "</\(tag)>" { break }
                    body.append(line)
                }
                let pem = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                switch tag {
                case "ca": parsed.ca = pem
                case "cert": parsed.cert = pem
                case "key": parsed.key = pem
                case "tls-auth": parsed.tlsAuth = pem
                case "tls-crypt", "tls-crypt-v2": parsed.tlsCrypt = pem
                case "secret": parsed.staticKey = pem
                default: break
                }
                continue
            }

            let parts = splitDirective(trimmed)
            guard let head = parts.first?.lowercased() else { continue }
            switch head {
            case "remote":
                guard parts.count >= 2 else { continue }
                let host = parts[1]
                let port = parts.count >= 3 ? Int(parts[2]) ?? 1194 : 1194
                let proto = parts.count >= 4 ? normalizeProto(parts[3]) : nil
                parsed.remotes.append(Remote(host: host, port: port, proto: proto))
            case "proto":
                if parts.count >= 2 { parsed.proto = normalizeProto(parts[1]) }
            case "cipher":
                if parts.count >= 2 { parsed.cipher = parts[1] }
            case "auth":
                if parts.count >= 2 { parsed.auth = parts[1] }
            case "topology":
                if parts.count >= 2 { parsed.topology = parts[1] }
            case "ifconfig":
                if parts.count >= 2 { parsed.addresses.append(parts[1].contains("/") ? parts[1] : "\(parts[1])/32") }
                if parts.count >= 3 { parsed.peerAddress = parts[2] }
            case "key-direction":
                if parts.count >= 2 {
                    parsed.keyDirection = parts[1] == "1" ? "client" : (parts[1] == "0" ? "server" : parts[1])
                }
            case "remote-random":
                parsed.remoteRandom = true
            case "redirect-gateway":
                parsed.redirectGateway = true
            case "auth-user-pass":
                // Inline credentials are rare; keep empty so Core can prompt / fail clearly.
                break
            default:
                break
            }
        }

        if parsed.remotes.isEmpty {
            throw VPNDirectCoreError.malformedConfig(component: "openvpn", detail: "No remote directive")
        }
        return parsed
    }

    private static func splitDirective(_ line: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false
        for ch in line {
            if ch == "\"" {
                inQuote.toggle()
                continue
            }
            if !inQuote, ch.isWhitespace {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private static func normalizeProto(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.hasPrefix("tcp") { return "tcp" }
        return "udp"
    }
}
