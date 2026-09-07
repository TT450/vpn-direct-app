import Foundation

/// Parses Mieru client JSON/profile payloads into `NormalizedSubscription`.
///
/// The production Core overlay validates Mieru strictly: transport is TCP/UDP, credentials are
/// required, and either `server_port` or `server_ports` must be present. This adapter therefore
/// never manufactures TCP, credentials, or a port when the source did not provide them.
public enum MieruConfigAdapter {
    public static func parse(_ text: String) throws -> NormalizedSubscription {
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Invalid JSON")
        }

        let endpoints: [NormalizedNode]
        if let profiles = json["profiles"] as? [[String: Any]] {
            guard !profiles.isEmpty else {
                throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Empty profiles array")
            }
            // Fail closed: one malformed Mieru profile must not silently disappear from a subscription.
            endpoints = try profiles.map(node(from:))
        } else {
            endpoints = [try node(from: json)]
        }

        let location = NormalizedLocation(
            id: "mieru",
            name: "Mieru",
            kind: .group,
            strategy: endpoints.count > 1 ? .urltest : .single,
            endpoints: endpoints
        )
        return NormalizedSubscription(name: "Mieru", locations: [location])
    }

    private static func node(from profile: [String: Any]) throws -> NormalizedNode {
        let server = ((profile["serverAddress"] as? String)
            ?? (profile["server"] as? String)
            ?? (profile["ipAddress"] as? String)
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !server.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Missing server")
        }
        guard !EndpointValidator.isBlockedLoopbackHost(server) else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Loopback/test server is not a usable endpoint")
        }

        let port: Int? = {
            if let n = profile["serverPort"] as? Int { return n }
            if let n = profile["port"] as? Int { return n }
            if let s = profile["serverPort"] as? String { return Int(s) }
            if let s = profile["port"] as? String { return Int(s) }
            return nil
        }()

        let serverPorts: [String] = {
            if let values = profile["serverPorts"] as? [String] { return values }
            if let values = profile["server_ports"] as? [String] { return values }
            if let value = profile["server_ports"] as? String {
                return value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return []
        }()

        guard let port, (1...65535).contains(port) else {
            if !serverPorts.isEmpty {
                // `NormalizedNode.port` and the current production Mieru builder cannot yet represent
                // server_ports-only profiles without inventing a primary port. Fail instead of losing semantics.
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "mieru.server_ports",
                    detail: "server_ports-only Mieru profiles require the typed Mieru endpoint model"
                )
            }
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Missing or invalid server port")
        }

        let transportRaw = ((profile["transport"] as? String) ?? (profile["protocol"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard transportRaw == "TCP" || transportRaw == "UDP" else {
            throw VPNDirectCoreError.malformedConfig(
                component: "mieru",
                detail: "transport must be explicitly TCP or UDP"
            )
        }

        let username = ((profile["userName"] as? String) ?? (profile["username"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let password = ((profile["password"] as? String) ?? (profile["userPassword"] as? String) ?? "")
        guard !username.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Missing username")
        }
        guard !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Missing password")
        }

        var attrs: [String: String] = [
            "username": username,
            "password": password,
            "transport": transportRaw,
        ]

        if !serverPorts.isEmpty {
            attrs["server_ports"] = serverPorts.joined(separator: ",")
        }
        if let multiplexing = profile["multiplexing"] as? String, !multiplexing.isEmpty {
            attrs["multiplexing"] = multiplexing
        }
        if let pattern = (profile["trafficPattern"] as? String) ?? (profile["traffic_pattern"] as? String),
           !pattern.isEmpty
        {
            // This is the exact encoded traffic-pattern string consumed by the Core overlay.
            attrs["traffic_pattern"] = pattern
        } else if profile["lowEntropy"] != nil || profile["low_entropy"] != nil {
            // A low-entropy mode/value is not the same thing as the Core overlay's encoded traffic pattern.
            // Do not stringify Bool/Int and pretend it is a valid Mieru traffic pattern.
            throw VPNDirectCoreError.unsupportedFeature(
                component: "mieru.low_entropy",
                detail: "Low-entropy source options require explicit translation to the current Mieru traffic-pattern schema"
            )
        }

        let name = ((profile["profileName"] as? String) ?? (profile["name"] as? String) ?? "Mieru")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return NormalizedNode(
            name: name.isEmpty ? "Mieru" : name,
            protocolID: .mieru,
            server: server,
            port: port,
            transport: VPNDirectTransportID(rawValue: transportRaw.lowercased()),
            attributes: attrs
        )
    }
}
