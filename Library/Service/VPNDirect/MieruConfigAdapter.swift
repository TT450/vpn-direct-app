import Foundation

/// Parses Mieru client JSON / profile payloads into NormalizedSubscription.
/// Capability-gated: outbound build fails closed until Core registers mieru.
public enum MieruConfigAdapter {
    public static func parse(_ text: String) throws -> NormalizedSubscription {
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Invalid JSON")
        }

        var endpoints: [NormalizedNode] = []

        if let profiles = json["profiles"] as? [[String: Any]] {
            for profile in profiles {
                if let node = node(from: profile) { endpoints.append(node) }
            }
        } else if let node = node(from: json) {
            endpoints.append(node)
        }

        guard !endpoints.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "No Mieru profiles found")
        }

        // Still allow parse when capability is false — builder rejects at emit time.
        let location = NormalizedLocation(
            id: "mieru",
            name: "Mieru",
            kind: .group,
            strategy: endpoints.count > 1 ? .select : .single,
            endpoints: endpoints
        )
        return NormalizedSubscription(name: "Mieru", locations: [location])
    }

    private static func node(from profile: [String: Any]) -> NormalizedNode? {
        let server = (profile["serverAddress"] as? String)
            ?? (profile["server"] as? String)
            ?? (profile["ipAddress"] as? String)
            ?? ""
        let port: Int = {
            if let n = profile["serverPort"] as? Int { return n }
            if let n = profile["port"] as? Int { return n }
            if let s = profile["serverPort"] as? String { return Int(s) ?? 0 }
            return 0
        }()
        guard !server.isEmpty, port > 0 else { return nil }
        if EndpointValidator.isBlockedLoopbackHost(server) { return nil }

        var attrs: [String: String] = [:]
        if let user = profile["userName"] as? String ?? profile["username"] as? String {
            attrs["username"] = user
        }
        if let pass = profile["password"] as? String ?? profile["userPassword"] as? String {
            attrs["password"] = pass
        }
        let transport = (profile["transport"] as? String)
            ?? (profile["protocol"] as? String)
            ?? "TCP"
        attrs["transport"] = transport.uppercased()
        if let multiplexing = profile["multiplexing"] as? String {
            attrs["multiplexing"] = multiplexing
        }
        // Low entropy → traffic_pattern string aligned with mbox outbound JSON.
        if let pattern = profile["trafficPattern"] as? String
            ?? profile["traffic_pattern"] as? String
        {
            attrs["traffic_pattern"] = pattern
        } else if let le = profile["lowEntropy"] ?? profile["low_entropy"] {
            attrs["traffic_pattern"] = "\(le)"
        }
        if let ports = profile["serverPorts"] as? [String] ?? profile["server_ports"] as? [String] {
            attrs["server_ports"] = ports.joined(separator: ",")
        } else if let ports = profile["server_ports"] as? String {
            attrs["server_ports"] = ports
        }
        let name = (profile["profileName"] as? String) ?? (profile["name"] as? String) ?? "Mieru"
        return NormalizedNode(
            name: name,
            protocolID: .mieru,
            server: server,
            port: port,
            attributes: attrs
        )
    }
}
