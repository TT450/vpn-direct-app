import Foundation
import Network

#if os(iOS)

/// Resolve sing-box outbound tags → host:port and measure TCP connect latency.
/// Used when VPN is off (Happ-style offline probe of node endpoints).
enum ServerEndpointPing {
    struct Endpoint: Hashable, Sendable {
        let host: String
        let port: UInt16
    }

    static func index(fromJSON json: String) -> [String: Endpoint] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = root["outbounds"] as? [[String: Any]]
        else { return [:] }

        var leaves: [String: Endpoint] = [:]
        var groups: [String: [String]] = [:]

        for outbound in outbounds {
            guard let tag = outbound["tag"] as? String, !tag.isEmpty else { continue }
            let type = (outbound["type"] as? String)?.lowercased() ?? ""
            if type == "selector" || type == "urltest" {
                if let members = outbound["outbounds"] as? [String], !members.isEmpty {
                    groups[tag] = members
                }
                continue
            }
            if let endpoint = leafEndpoint(outbound) {
                leaves[tag] = endpoint
            }
        }

        var resolved = leaves
        for tag in groups.keys {
            if let endpoint = resolveGroup(tag, leaves: leaves, groups: groups, depth: 0) {
                resolved[tag] = endpoint
            }
        }
        return resolved
    }

    static func measure(host: String, port: UInt16, timeout: TimeInterval = 3.0) async -> Int? {
        await withCheckedContinuation { continuation in
            let nwHost = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: nil)
                return
            }
            let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
            let start = Date()
            let lock = NSLock()
            var resumed = false

            func finish(_ value: Int?) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(max(1, Int(Date().timeIntervalSince(start) * 1000)))
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                finish(nil)
            }
        }
    }

    private static func resolveGroup(
        _ tag: String,
        leaves: [String: Endpoint],
        groups: [String: [String]],
        depth: Int
    ) -> Endpoint? {
        if let leaf = leaves[tag] { return leaf }
        guard depth < 6, let members = groups[tag] else { return nil }
        for member in members {
            if let endpoint = resolveGroup(member, leaves: leaves, groups: groups, depth: depth + 1) {
                return endpoint
            }
        }
        return nil
    }

    private static func leafEndpoint(_ outbound: [String: Any]) -> Endpoint? {
        if let host = stringValue(outbound["server"]),
           let port = portValue(outbound["server_port"]),
           !host.isEmpty, port > 0
        {
            return Endpoint(host: host, port: port)
        }
        if let peers = outbound["peers"] as? [[String: Any]],
           let address = stringValue(peers.first?["address"] ?? peers.first?["server"])
        {
            let parts = address.split(separator: ":")
            if parts.count >= 2, let port = UInt16(parts.last!) {
                return Endpoint(host: parts.dropLast().joined(separator: ":"), port: port)
            }
        }
        if let host = stringValue(outbound["server"]),
           let ports = outbound["server_ports"] as? [String],
           let first = ports.first
        {
            let token = first.split(whereSeparator: { $0 == "-" || $0 == ":" || $0 == "/" }).first.map(String.init) ?? first
            if let port = UInt16(token), port > 0 {
                return Endpoint(host: host, port: port)
            }
        }
        return nil
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let value = any as? String { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = any as? NSNumber { return value.stringValue }
        return nil
    }

    private static func portValue(_ any: Any?) -> UInt16? {
        if let value = any as? Int, value > 0, value <= Int(UInt16.max) { return UInt16(value) }
        if let value = any as? NSNumber {
            let intValue = value.intValue
            if intValue > 0, intValue <= Int(UInt16.max) { return UInt16(intValue) }
        }
        if let value = any as? String, let intValue = UInt16(value) { return intValue }
        return nil
    }
}

#endif
