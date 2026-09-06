import Foundation

/// Parses Mieru client JSON / profile payloads into NormalizedSubscription.
/// Capability-gated: outbound build fails closed until Core registers mieru.
enum MieruConfigAdapter {
    static func parse(_ text: String) throws -> NormalizedSubscription {
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
            kind: .country,
            strategy: endpoints.count > 1 ? .urltest : .single,
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
        if let mtu = profile["mtu"] as? Int { attrs["mtu"] = String(mtu) }
        if let mtu = profile["mtu"] as? String { attrs["mtu"] = mtu }
        if let multiplexing = profile["multiplexing"] as? String {
            attrs["multiplexing"] = multiplexing
        }
        if let handshake = profile["handshakeMode"] as? String ?? profile["handshake_mode"] as? String {
            attrs["handshake_mode"] = handshake
        }
        // Low entropy as config-driven string (32/40/48/56…), not a closed enum.
        if let le = profile["lowEntropy"] ?? profile["low_entropy"] {
            attrs["low_entropy"] = "\(le)"
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
