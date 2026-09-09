import Foundation
import Libbox
import Network

#if os(iOS)

/// Happ-style latency probes for the server list UI.
/// Docs: https://www.happ.su/main/dev-docs/ping
///
/// - **via Proxy**: HTTP probe through a specific outbound (full path + TLS) — use when VPN is up.
/// - **TCP**: connect RTT to node `host:port` — use when VPN is off (no tunnel required).
/// - **ICMP**: not used on iOS (needs tunnel pause / raw sockets; Happ disables the tunnel for it).
enum ServerEndpointPing {
    static let probeURL = "https://www.gstatic.com/generate_204"
    static let viaProxyTimeoutMs: Int32 = 5000
    static let tcpTimeout: TimeInterval = 3.0
    /// Cap parallel via-Proxy probes so the command channel stays responsive.
    static let viaProxyConcurrency = 8

    struct Endpoint: Hashable, Sendable {
        let host: String
        let port: UInt16
    }

    enum Mode: String {
        case viaProxy
        case tcp

        var label: String {
            switch self {
            case .viaProxy: return "VIA PROXY"
            case .tcp: return "TCP"
            }
        }
    }

    static func preferredMode(isConnected: Bool) -> Mode {
        isConnected ? .viaProxy : .tcp
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

    /// Happ **TCP Ping**: TCP handshake RTT to the node endpoint (no HTTP, no tunnel).
    static func measureTCP(host: String, port: UInt16, timeout: TimeInterval = tcpTimeout) async -> Int? {
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

    /// Happ **via Proxy Ping**: GET/HEAD through the outbound to `probeURL` (full path + TLS).
    /// Uses Libbox `urlTestOutbound` so the live selector is not switched.
    static func measureViaProxy(outboundTag: String, link: String = probeURL, timeoutMs: Int32 = viaProxyTimeoutMs) async -> Int? {
        await Task.detached(priority: .userInitiated) {
            do {
                guard let client = LibboxNewStandaloneCommandClient() else { return nil as Int? }
                let result = try client.urlTestOutbound(outboundTag, link: link, timeout: timeoutMs)
                if !result.error.isEmpty { return nil }
                // Delay 0 with empty error is a valid fast success (Libbox Variant B).
                return max(1, Int(result.delay))
            } catch {
                return nil
            }
        }.value
    }

    /// Parallel via-Proxy sweep with a bounded worker pool.
    static func measureViaProxyAll(tags: [String]) async -> [String: Int] {
        guard !tags.isEmpty else { return [:] }
        var delays: [String: Int] = [:]
        delays.reserveCapacity(tags.count)

        await withTaskGroup(of: (String, Int?).self) { group in
            var next = 0
            let limit = min(viaProxyConcurrency, tags.count)

            func spawn() {
                guard next < tags.count else { return }
                let tag = tags[next]
                next += 1
                group.addTask {
                    let ms = await measureViaProxy(outboundTag: tag)
                    return (tag, ms)
                }
            }

            for _ in 0 ..< limit {
                spawn()
            }
            for await (tag, ms) in group {
                if let ms { delays[tag] = ms }
                spawn()
            }
        }
        return delays
    }

    /// Parallel TCP sweep (offline) with a bounded worker pool.
    static let tcpConcurrency = 10

    static func measureTCPAll(endpoints: [String: Endpoint], serverIDs: [String]) async -> [String: Int] {
        let ids = serverIDs.filter { endpoints[$0] != nil }
        guard !ids.isEmpty else { return [:] }
        var delays: [String: Int] = [:]
        delays.reserveCapacity(ids.count)

        await withTaskGroup(of: (String, Int?).self) { group in
            var next = 0
            let limit = min(tcpConcurrency, ids.count)

            func spawn() {
                guard next < ids.count else { return }
                let id = ids[next]
                next += 1
                group.addTask {
                    guard let endpoint = endpoints[id] else { return (id, nil) }
                    let ms = await measureTCP(host: endpoint.host, port: endpoint.port)
                    return (id, ms)
                }
            }

            for _ in 0 ..< limit {
                spawn()
            }
            for await (id, ms) in group {
                if let ms { delays[id] = ms }
                spawn()
            }
        }
        return delays
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
