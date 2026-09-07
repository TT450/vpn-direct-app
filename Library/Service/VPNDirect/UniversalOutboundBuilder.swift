import Foundation

/// Builds sing-box outbound dictionaries from NormalizedNode fields (no pre-built outbound required).
public enum UniversalOutboundBuilder {
    public static func build(from node: NormalizedNode) throws -> [String: Any] {
        // LEGACY outbound already encodes mapped Core JSON — do not re-fail on preserved Xray stream dumps.
        // Attributes-only path: refuse connection-critical unknowns that builders do not consume.
        if node.outbound == nil || node.outbound?.isEmpty == true {
            let candidateKeys = Set(node.attributes.keys)
                .union(node.rawExtensions.keys)
                .filter { key in
                    let k = key.lowercased()
                    if k.hasPrefix("xray") { return false }
                    if k.hasPrefix("stream.") || k.hasPrefix("settings.") {
                        // Keep connection-critical nested unknowns in the fail-closed scan.
                        return CompatibilityFieldPolicy.classify(key: key) == .connectionCritical
                    }
                    return true
                }
            try CompatibilityFieldPolicy.assertNoCriticalUnknowns(
                allKeys: candidateKeys,
                consumedKeys: CompatibilityFieldPolicy.knownProtocolKeys,
                ecosystem: "builder",
                protocolID: node.protocolID.rawValue
            )
        }

        // LEGACY: pre-built outbound dictionaries from older converters.
        // Prefer attributes-only NormalizedNode; keep this early-return until remaining writers migrate.
        if let existing = node.outbound, !existing.isEmpty {
            var copy = existing
            if copy["tag"] == nil { copy["tag"] = node.name }
            return copy
        }
        switch node.protocolID {
        case .vless:
            return try buildVLESS(node)
        case .vmess:
            return try buildVMess(node)
        case .trojan:
            return try buildTrojan(node)
        case .shadowsocks:
            return try buildShadowsocks(node)
        case .hysteria, .hysteria2:
            guard let built = HysteriaOutboundFactory.fromShareLink(node.source ?? "", fallbackTag: node.name)
                    ?? HysteriaOutboundFactory.fromAttributes(node)
            else {
                throw VPNDirectCoreError.malformedConfig(component: "hysteria", detail: "Missing Hysteria fields")
            }
            return built
        case .tuic:
            return try buildTUIC(node)
        case .anytls:
            return try buildAnyTLS(node)
        case .wireguard, .amneziawg:
            return try buildWireGuard(node)
        case .socks:
            return try buildSOCKS(node)
        case .http:
            return try buildHTTP(node)
        case .ssh:
            return try buildSSH(node)
        case .masque:
            return try buildMasque(node)
        case .mieru:
            return try buildMieru(node)
        default:
            if node.protocolID.rawValue == "shadowtls" {
                return try buildShadowTLS(node)
            }
            if node.protocolID.rawValue == "naive" {
                return try buildNaive(node)
            }
            throw VPNDirectCoreError.unsupportedFeature(
                component: node.protocolID.rawValue,
                detail: "No outbound builder for protocol"
            )
        }
    }

    private static func buildShadowTLS(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "shadowtls",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
        ]
        if let version = attr(node, "version").flatMap(Int.init) { outbound["version"] = version }
        if let password = attr(node, "password") { outbound["password"] = password }
        if let tls = tlsObject(from: node, defaultSNI: node.server) { outbound["tls"] = tls }
        return outbound
    }

    private static func buildNaive(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "naive",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
        ]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let network = attr(node, "network") { outbound["quic"] = network == "quic" }
        return outbound
    }

    // MARK: - Helpers

    private static func attr(_ node: NormalizedNode, _ key: String) -> String? {
        let aliases: [String: [String]] = [
            "pbk": ["pbk", "public-key", "public_key"],
            "sid": ["sid", "short-id", "short_id"],
            "fp": ["fp", "client-fingerprint", "client_fingerprint", "fingerprint"],
            "sni": ["sni", "servername", "server_name"],
            "path": ["path", "ws-path"],
            "service_name": ["service_name", "grpc-service-name", "grpc_service_name"],
            "plugin_opts": ["plugin_opts", "plugin-opts"],
            "transport": ["transport"],
            "traffic_pattern": ["traffic_pattern", "traffic-pattern", "low_entropy", "low-entropy"],
        ]
        let keys = aliases[key] ?? [key, key.lowercased()]
        for k in keys {
            if let v = node.attributes[k] ?? node.attributes[k.lowercased()], !v.isEmpty {
                return v
            }
        }
        return nil
    }

    private static func tlsObject(from node: NormalizedNode, defaultSNI: String) -> [String: Any]? {
        let securityRaw = node.security?.rawValue ?? attr(node, "security") ?? "none"
        let hasReality = securityRaw == "reality"
            || attr(node, "pbk") != nil
            || node.attributes.keys.contains(where: { $0.hasPrefix("reality-opts") || $0 == "public-key" })
        let security = hasReality ? "reality" : securityRaw
        guard security == "tls" || security == "reality" else { return nil }
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": attr(node, "sni") ?? attr(node, "peer") ?? defaultSNI,
        ]
        if attr(node, "insecure") == "1" || attr(node, "allowInsecure") == "1" {
            tls["insecure"] = true
        }
        if let alpn = attr(node, "alpn") {
            tls["alpn"] = alpn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        if let fp = attr(node, "fp"), !fp.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": fp]
        }
        if security == "reality" {
            var reality: [String: Any] = ["enabled": true]
            if let pbk = attr(node, "pbk") { reality["public_key"] = pbk }
            if let sid = attr(node, "sid") { reality["short_id"] = sid }
            tls["reality"] = reality
        }
        return tls
    }

    private static func transportObject(from node: NormalizedNode) -> [String: Any]? {
        let t = (node.transport?.rawValue
            ?? attr(node, "network")
            ?? attr(node, "net")
            ?? attr(node, "type")
            ?? "tcp").lowercased()
        switch t {
        case "ws", "websocket":
            var ws: [String: Any] = ["type": "ws"]
            if let path = attr(node, "path") { ws["path"] = path }
            if let host = attr(node, "host") {
                ws["headers"] = ["Host": host]
            }
            return ws
        case "grpc":
            var grpc: [String: Any] = ["type": "grpc"]
            if let service = attr(node, "service_name") ?? attr(node, "serviceName") ?? attr(node, "servicename") {
                grpc["service_name"] = service
            }
            return grpc
        case "httpupgrade":
            var hu: [String: Any] = ["type": "httpupgrade"]
            if let path = attr(node, "path") { hu["path"] = path }
            if let host = attr(node, "host") { hu["host"] = host }
            return hu
        case "http", "h2":
            var http: [String: Any] = ["type": "http"]
            if let path = attr(node, "path") { http["path"] = [path] }
            if let host = attr(node, "host") { http["host"] = [host] }
            return http
        case "xhttp", "splithttp":
            var xhttp: [String: Any] = ["type": "xhttp"]
            if let path = attr(node, "path") { xhttp["path"] = path } else { xhttp["path"] = "/" }
            if let host = attr(node, "host") { xhttp["host"] = host }
            xhttp["mode"] = attr(node, "mode") ?? "auto"
            if let extra = attr(node, "extra") { xhttp["extra"] = extra }
            if let sc = attr(node, "scMaxEachPostBytes") ?? attr(node, "sc_max_each_post_bytes") {
                xhttp["sc_max_each_post_bytes"] = sc
            }
            if let sc = attr(node, "scMinPostsIntervalMs") ?? attr(node, "sc_min_posts_interval_ms") {
                xhttp["sc_min_posts_interval_ms"] = sc
            }
            if let sc = attr(node, "scMaxConcurrentPosts") ?? attr(node, "sc_max_concurrent_posts") {
                xhttp["sc_max_concurrent_posts"] = sc
            }
            if let pad = attr(node, "x_padding_bytes") ?? attr(node, "xPaddingBytes") {
                xhttp["x_padding_bytes"] = pad
            }
            return xhttp
        default:
            return nil
        }
    }

    // MARK: - Protocol builders

    private static func buildVLESS(_ node: NormalizedNode) throws -> [String: Any] {
        guard let uuid = node.uuid ?? attr(node, "uuid"), !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "vless", detail: "Missing uuid")
        }
        let network = (node.transport?.rawValue ?? attr(node, "network") ?? attr(node, "net") ?? "tcp").lowercased()
        if network == "xhttp" || network == "splithttp" {
            guard VPNDirectCoreCapabilities.current.supportsXHTTP else {
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "xhttp",
                    detail: "Current Libbox build lacks native xhttp transport"
                )
            }
        }
        var outbound: [String: Any] = [
            "type": "vless",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "uuid": uuid,
        ]
        if let flow = attr(node, "flow") { outbound["flow"] = flow }
        if let tls = tlsObject(from: node, defaultSNI: node.server) { outbound["tls"] = tls }
        if let transport = transportObject(from: node) { outbound["transport"] = transport }
        if let encryption = attr(node, "encryption") { outbound["encryption"] = encryption }
        if let packet = attr(node, "packet_encoding") { outbound["packet_encoding"] = packet }
        return outbound
    }

    private static func buildVMess(_ node: NormalizedNode) throws -> [String: Any] {
        guard let uuid = node.uuid ?? attr(node, "id") ?? attr(node, "uuid"), !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing id")
        }
        var outbound: [String: Any] = [
            "type": "vmess",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "uuid": uuid,
            "security": attr(node, "scy") ?? attr(node, "security") ?? "auto",
        ]
        if let alterId = attr(node, "aid").flatMap(Int.init) {
            outbound["alter_id"] = alterId
        }
        let tlsMode = attr(node, "tls") ?? ""
        if tlsMode == "tls" || node.security == .tls || node.security == .reality {
            if let tls = tlsObject(from: node, defaultSNI: node.server) {
                outbound["tls"] = tls
            } else {
                outbound["tls"] = ["enabled": true, "server_name": attr(node, "sni") ?? node.server]
            }
        }
        if let transport = transportObject(from: node) { outbound["transport"] = transport }
        return outbound
    }

    private static func buildTrojan(_ node: NormalizedNode) throws -> [String: Any] {
        guard let password = attr(node, "password") ?? node.uuid, !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Missing password")
        }
        var outbound: [String: Any] = [
            "type": "trojan",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "password": password,
        ]
        if let tls = tlsObject(from: node, defaultSNI: node.server) {
            outbound["tls"] = tls
        } else {
            outbound["tls"] = ["enabled": true, "server_name": attr(node, "sni") ?? node.server]
        }
        if let transport = transportObject(from: node) { outbound["transport"] = transport }
        return outbound
    }

    private static func buildShadowsocks(_ node: NormalizedNode) throws -> [String: Any] {
        guard let method = attr(node, "method") ?? attr(node, "cipher"), !method.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Missing method")
        }
        guard let password = attr(node, "password"), !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Missing password")
        }
        var outbound: [String: Any] = [
            "type": "shadowsocks",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "method": method,
            "password": password,
        ]
        if let plugin = attr(node, "plugin") {
            outbound["plugin"] = plugin
            if let opts = attr(node, "plugin_opts") { outbound["plugin_opts"] = opts }
        }
        return outbound
    }

    private static func buildTUIC(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "tuic",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
        ]
        if let uuid = node.uuid ?? attr(node, "uuid") { outbound["uuid"] = uuid }
        if let password = attr(node, "password") { outbound["password"] = password }
        if let cc = attr(node, "congestion_control") ?? attr(node, "congestion") {
            outbound["congestion_control"] = cc
        }
        if let udpRelay = attr(node, "udp_relay_mode") {
            outbound["udp_relay_mode"] = udpRelay
        }
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": attr(node, "sni") ?? node.server,
        ]
        if attr(node, "insecure") == "1" { tls["insecure"] = true }
        if let alpn = attr(node, "alpn") {
            tls["alpn"] = alpn.split(separator: ",").map(String.init)
        }
        outbound["tls"] = tls
        return outbound
    }

    private static func buildAnyTLS(_ node: NormalizedNode) throws -> [String: Any] {
        guard let password = attr(node, "password"), !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "anytls", detail: "Missing password")
        }
        // Do not inject client/device metadata (sing-box privacy default).
        var outbound: [String: Any] = [
            "type": "anytls",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "password": password,
        ]
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": attr(node, "sni") ?? node.server,
        ]
        if attr(node, "insecure") == "1" { tls["insecure"] = true }
        outbound["tls"] = tls
        return outbound
    }

    private static func buildWireGuard(_ node: NormalizedNode) throws -> [String: Any] {
        guard let privateKey = attr(node, "private_key") ?? attr(node, "privateKey"), !privateKey.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing private key")
        }
        guard let peerKey = attr(node, "peer_public_key") ?? attr(node, "public_key") ?? attr(node, "publicKey"),
              !peerKey.isEmpty
        else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing peer public key")
        }
        let localAddress = (attr(node, "local_address") ?? attr(node, "address") ?? "10.0.0.2/32")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var outbound: [String: Any] = [
            "type": "wireguard",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "private_key": privateKey,
            "peer_public_key": peerKey,
            "local_address": localAddress,
        ]
        if let psk = attr(node, "pre_shared_key") ?? attr(node, "preshared_key") {
            outbound["pre_shared_key"] = psk
        }
        if let mtu = attr(node, "mtu").flatMap(Int.init) { outbound["mtu"] = mtu }
        if node.protocolID == .amneziawg || attr(node, "amnezia_version") != nil {
            if !VPNDirectCoreCapabilities.current.supportsAWG {
                throw VPNDirectCoreError.unsupportedFeature(component: "amneziawg", detail: "Current Libbox build lacks with_awg")
            }
            // sing-box embeds AmneziaWGOptions on the wireguard object (no "amnezia" wrapper).
            for key in ["jc", "jmin", "jmax", "s1", "s2", "s3", "s4"] {
                if let n = attr(node, key).flatMap(Int.init) { outbound[key] = n }
            }
            for key in ["h1", "h2", "h3", "h4", "i1", "i2", "i3", "i4", "i5"] {
                if let s = attr(node, key) { outbound[key] = s }
            }
        }
        return outbound
    }

    private static func buildSOCKS(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "socks",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "version": attr(node, "version") ?? "5",
        ]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        return outbound
    }

    private static func buildHTTP(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "http",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
        ]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let tls = tlsObject(from: node, defaultSNI: node.server) { outbound["tls"] = tls }
        return outbound
    }

    private static func buildSSH(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "ssh",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "user": attr(node, "user") ?? attr(node, "username") ?? "root",
        ]
        if let password = attr(node, "password") { outbound["password"] = password }
        if let key = attr(node, "private_key") { outbound["private_key"] = key }
        if let path = attr(node, "private_key_path") { outbound["private_key_path"] = path }
        return outbound
    }

    private static func buildMasque(_ node: NormalizedNode) throws -> [String: Any] {
        guard let privateKey = attr(node, "private_key"), let publicKey = attr(node, "public_key") else {
            throw VPNDirectCoreError.malformedConfig(component: "masque", detail: "Missing WARP/MASQUE keys")
        }
        return try MasqueOutboundOptions(
            server: node.server,
            serverPort: node.port,
            profile: attr(node, "profile") ?? "cloudflare",
            vhttp: attr(node, "vhttp") ?? "h3",
            privateKey: privateKey,
            publicKey: publicKey,
            ip: attr(node, "ip"),
            ipv6: attr(node, "ipv6"),
            tlsServerName: attr(node, "sni")
        ).outboundJSON(tag: node.name)
    }

    private static func buildMieru(_ node: NormalizedNode) throws -> [String: Any] {
        guard VPNDirectCoreCapabilities.current.supportsMieru else {
            throw VPNDirectCoreError.unsupportedFeature(
                component: "mieru",
                detail: "Mieru runtime not registered in this Libbox build"
            )
        }
        var outbound: [String: Any] = [
            "type": "mieru",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            // mbox / enfein mieru require transport TCP|UDP
            "transport": (attr(node, "transport") ?? "TCP").uppercased(),
        ]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let multiplexing = attr(node, "multiplexing") { outbound["multiplexing"] = multiplexing }
        // Low entropy is encoded as traffic_pattern string (not a closed enum).
        if let pattern = attr(node, "traffic_pattern") {
            outbound["traffic_pattern"] = pattern
        }
        if let ports = attr(node, "server_ports") {
            outbound["server_ports"] = ports.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        return outbound
    }
}

extension HysteriaOutboundFactory {
    static func fromAttributes(_ node: NormalizedNode) -> [String: Any]? {
        let auth = node.attributes["auth"] ?? node.attributes["password"] ?? node.uuid
        guard let auth, !auth.isEmpty, !node.server.isEmpty, node.port > 0 else { return nil }
        let isV2 = node.protocolID == .hysteria2
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": node.attributes["sni"] ?? node.server,
        ]
        if node.attributes["insecure"] == "1" { tls["insecure"] = true }
        if isV2 { tls["alpn"] = ["h3"] }
        var outbound: [String: Any] = [
            "type": isV2 ? "hysteria2" : "hysteria",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "tls": tls,
        ]
        if isV2 {
            outbound["password"] = auth
        } else {
            outbound["auth_str"] = auth
        }
        if let up = node.attributes["up"].flatMap(Int.init) { outbound["up_mbps"] = up }
        if let down = node.attributes["down"].flatMap(Int.init) { outbound["down_mbps"] = down }
        if let obfs = node.attributes["obfs"] {
            if isV2 {
                outbound["obfs"] = ["type": obfs, "password": node.attributes["obfs_password"] ?? ""]
            } else {
                outbound["obfs"] = obfs
            }
        }
        return outbound
    }
}
