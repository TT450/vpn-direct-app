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
        // Still fail-closed on connection-critical encryption present in prebuilt JSON when capability missing.
        if let existing = node.outbound, !existing.isEmpty {
            if let enc = existing["encryption"] as? String,
               !enc.isEmpty,
               enc.lowercased() != "none",
               !VPNDirectCoreCapabilities.current.supportsVLESSEncryption
            {
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "vless.encryption",
                    detail: "VLESS encryption/PQ present in legacy outbound but unsupported by current Libbox"
                )
            }
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
            // Production builder must emit from normalized attributes, never re-parse `source`.
            guard let built = HysteriaOutboundFactory.fromAttributes(node) else {
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
        case .naive:
            return try buildNaive(node)
        case .shadowtls:
            return try buildShadowTLS(node)
        default:
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
        let quicRequested = attr(node, "quic") == "1"
            || attr(node, "quic")?.lowercased() == "true"
            || attr(node, "network") == "quic"
        if quicRequested { outbound["quic"] = true }
        if let insecureConcurrency = attr(node, "insecure_concurrency").flatMap(Int.init) {
            outbound["insecure_concurrency"] = insecureConcurrency
        }
        if let window = attr(node, "stream_receive_window") ?? attr(node, "receive_window") {
            outbound["stream_receive_window"] = window
        }
        if let quicCC = attr(node, "quic_congestion_control") {
            outbound["quic_congestion_control"] = quicCC
        }
        if let quicWindow = attr(node, "quic_session_receive_window") {
            outbound["quic_session_receive_window"] = quicWindow
        }
        if boolAttr(node, "udp_over_tcp") {
            outbound["udp_over_tcp"] = true
        }
        // Naive requires TLS when not using QUIC-only path semantics — always emit TLS object.
        if let tls = tlsObject(from: node, defaultSNI: node.server) {
            outbound["tls"] = tls
        } else {
            outbound["tls"] = [
                "enabled": true,
                "server_name": attr(node, "sni") ?? attr(node, "server_name") ?? node.server,
            ]
        }
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
        if attr(node, "tls_fragment") == "1" || attr(node, "fragment") == "1" {
            tls["fragment"] = true
        }
        if let delay = attr(node, "tls_fragment_fallback_delay"), !delay.isEmpty {
            tls["fragment_fallback_delay"] = delay
        }
        return tls
    }

    private static func applyMultiplexAndTLSFragment(from node: NormalizedNode, into outbound: inout [String: Any]) {
        if let multiplex = XrayMuxAndMask.multiplexFromAttrs(node.attributes) {
            outbound["multiplex"] = multiplex
        } else if attr(node, "multiplex") == "1" || attr(node, "mux") == "1" {
            outbound["multiplex"] = ["enabled": true]
        }
        // Fragment may have been applied via tlsObject; ensure when tls was synthesized elsewhere.
        if attr(node, "tls_fragment") == "1" || attr(node, "fragment") == "1" {
            var tls = (outbound["tls"] as? [String: Any]) ?? ["enabled": true]
            tls["fragment"] = true
            if let delay = attr(node, "tls_fragment_fallback_delay"), !delay.isEmpty {
                tls["fragment_fallback_delay"] = delay
            }
            outbound["tls"] = tls
        }
    }

    private static func transportObject(from node: NormalizedNode) throws -> [String: Any]? {
        let explicit = node.transport?.rawValue
            ?? attr(node, "network")
            ?? attr(node, "net")
            ?? attr(node, "type")
        let t = (explicit ?? "tcp").lowercased()
        switch t {
        case "tcp", "raw", "":
            return nil
        case "ws", "websocket":
            var ws: [String: Any] = ["type": "ws"]
            if let path = attr(node, "path") { ws["path"] = path }
            if let host = attr(node, "host") {
                ws["headers"] = ["Host": host]
            }
            if let early = attr(node, "max_early_data").flatMap(Int.init) {
                ws["max_early_data"] = early
            }
            if let header = attr(node, "early_data_header_name") {
                ws["early_data_header_name"] = header
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
            if let extra = attr(node, "extra") {
                // Prefer structured JSON object when possible.
                if let data = extra.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data)
                {
                    xhttp["extra"] = obj
                } else {
                    xhttp["extra"] = extra
                }
            }
            if let sc = attr(node, "scMaxEachPostBytes") ?? attr(node, "sc_max_each_post_bytes"),
               let n = Int(sc)
            {
                xhttp["sc_max_each_post_bytes"] = n
            } else if let sc = attr(node, "scMaxEachPostBytes") ?? attr(node, "sc_max_each_post_bytes") {
                xhttp["sc_max_each_post_bytes"] = sc
            }
            if let sc = attr(node, "scMinPostsIntervalMs") ?? attr(node, "sc_min_posts_interval_ms"),
               let n = Int(sc)
            {
                xhttp["sc_min_posts_interval_ms"] = n
            } else if let sc = attr(node, "scMinPostsIntervalMs") ?? attr(node, "sc_min_posts_interval_ms") {
                xhttp["sc_min_posts_interval_ms"] = sc
            }
            if let sc = attr(node, "scMaxConcurrentPosts") ?? attr(node, "sc_max_concurrent_posts"),
               let n = Int(sc)
            {
                xhttp["sc_max_concurrent_posts"] = n
            } else if let sc = attr(node, "scMaxConcurrentPosts") ?? attr(node, "sc_max_concurrent_posts") {
                xhttp["sc_max_concurrent_posts"] = sc
            }
            if let pad = attr(node, "x_padding_bytes") ?? attr(node, "xPaddingBytes") {
                xhttp["x_padding_bytes"] = pad
            }
            return xhttp
        case "kcp", "mkcp", "quic", "domainsocket", "ds":
            throw VPNDirectCoreError.unsupportedFeature(
                component: "transport.\(t)",
                detail: "Unsupported V2Ray transport for current Core"
            )
        default:
            // Explicit unknown transport must not silently become TCP.
            if explicit != nil {
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "transport.\(t)",
                    detail: "Unknown transport"
                )
            }
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
        if let transport = try transportObject(from: node) { outbound["transport"] = transport }
        if let encryption = attr(node, "encryption"), !encryption.isEmpty, encryption.lowercased() != "none" {
            guard VPNDirectCoreCapabilities.current.supportsVLESSEncryption else {
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "vless.encryption",
                    detail: "VLESS encryption/PQ present but unsupported by current Libbox"
                )
            }
            outbound["encryption"] = encryption
        }
        if let packet = attr(node, "packet_encoding") { outbound["packet_encoding"] = packet }
        applyMultiplexAndTLSFragment(from: node, into: &outbound)
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
        if boolAttr(node, "global_padding") {
            outbound["global_padding"] = true
        }
        if boolAttr(node, "authenticated_length") {
            outbound["authenticated_length"] = true
        }
        if let pe = attr(node, "packet_encoding") {
            outbound["packet_encoding"] = pe
        }
        let tlsMode = attr(node, "tls") ?? ""
        if tlsMode == "tls" || node.security == .tls || node.security == .reality {
            if let tls = tlsObject(from: node, defaultSNI: node.server) {
                outbound["tls"] = tls
            } else {
                outbound["tls"] = ["enabled": true, "server_name": attr(node, "sni") ?? node.server]
            }
        }
        if let transport = try transportObject(from: node) { outbound["transport"] = transport }
        applyMultiplexAndTLSFragment(from: node, into: &outbound)
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
        if let transport = try transportObject(from: node) { outbound["transport"] = transport }
        applyMultiplexAndTLSFragment(from: node, into: &outbound)
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
        applyMultiplexAndTLSFragment(from: node, into: &outbound)
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
        if boolAttr(node, "udp_over_stream") {
            outbound["udp_over_stream"] = true
        }
        if boolAttr(node, "zero_rtt_handshake") || boolAttr(node, "zero_rtt") {
            outbound["zero_rtt_handshake"] = true
        }
        if let heartbeat = attr(node, "heartbeat"), !heartbeat.isEmpty {
            outbound["heartbeat"] = heartbeat
        }
        if let network = attr(node, "network"), !network.isEmpty {
            outbound["network"] = network
        }
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": attr(node, "sni") ?? node.server,
        ]
        if boolAttr(node, "insecure") { tls["insecure"] = true }
        if let alpn = attr(node, "alpn") {
            tls["alpn"] = alpn.split(separator: ",").map(String.init)
        }
        outbound["tls"] = tls
        return outbound
    }

    /// Typed bool from attributes — accepts 1/true/yes/on (case-insensitive).
    private static func boolAttr(_ node: NormalizedNode, _ key: String) -> Bool {
        guard let raw = attr(node, key)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else { return false }
        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
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
        if let options = node.wireguardEndpoint {
            return try options.endpointJSON(tag: node.name)
        }
        // Fallback: reconstruct structured options from flat attributes (share-link / Clash).
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
        let peerEndpoint: String
        if node.server.contains(":"), !node.server.hasPrefix("[") {
            // Bare IPv6 host — wrap for host:port form.
            peerEndpoint = "[\(node.server)]:\(node.port)"
        } else {
            peerEndpoint = "\(node.server):\(node.port)"
        }
        let forced = attr(node, "amnezia_version")
        let options = try AmneziaWGEndpointOptions.fromFlatAttributes(
            privateKey: privateKey,
            peerPublicKey: peerKey,
            localAddress: Array(localAddress),
            peerEndpoint: peerEndpoint,
            preSharedKey: attr(node, "pre_shared_key") ?? attr(node, "preshared_key"),
            mtu: attr(node, "mtu").flatMap(Int.init),
            attributes: node.attributes,
            forcedVersion: forced,
            claimedAWG: node.protocolID == .amneziawg && forced == nil
        )
        return try options.endpointJSON(tag: node.name)
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
        guard let user = attr(node, "user") ?? attr(node, "username"), !user.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "ssh", detail: "Missing user")
        }
        var outbound: [String: Any] = [
            "type": "ssh",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "user": user,
        ]
        if let password = attr(node, "password") { outbound["password"] = password }
        if let key = attr(node, "private_key") { outbound["private_key"] = key }
        if let path = attr(node, "private_key_path") { outbound["private_key_path"] = path }
        return outbound
    }

    private static func buildMasque(_ node: NormalizedNode) throws -> [String: Any] {
        let profile = (attr(node, "profile") ?? "").lowercased()
        guard !profile.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(
                component: "masque.profile",
                detail: "Explicit profile required (standard|cloudflare); no silent WARP default"
            )
        }
        guard profile == "standard" || profile == "cloudflare" else {
            throw VPNDirectCoreError.unsupportedFeature(
                component: "masque.profile",
                detail: "Unknown MASQUE profile \(profile)"
            )
        }
        let vhttp = attr(node, "vhttp")
        // Cloudflare/WARP identity requires keys; standard may also require them in current donor.
        guard let privateKey = attr(node, "private_key"), let publicKey = attr(node, "public_key") else {
            throw VPNDirectCoreError.malformedConfig(
                component: "masque",
                detail: profile == "cloudflare" ? "Missing WARP keys" : "Missing MASQUE keys"
            )
        }
        return try MasqueOutboundOptions(
            server: node.server,
            serverPort: node.port,
            profile: profile,
            vhttp: vhttp ?? (profile == "cloudflare" ? "h3" : "h3"),
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
        guard let transportRaw = attr(node, "transport"), !transportRaw.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(
                component: "mieru.transport",
                detail: "Missing transport (TCP|UDP); refusing silent TCP default"
            )
        }
        let transport = transportRaw.uppercased()
        guard transport == "TCP" || transport == "UDP" else {
            throw VPNDirectCoreError.unsupportedFeature(
                component: "mieru.transport",
                detail: "Unsupported Mieru transport \(transport)"
            )
        }
        var outbound: [String: Any] = [
            "type": "mieru",
            "tag": node.name,
            "server": node.server,
            "server_port": node.port,
            "transport": transport,
        ]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let multiplexing = attr(node, "multiplexing") { outbound["multiplexing"] = multiplexing }
        // Low entropy is encoded as traffic_pattern string (not a closed enum / bool).
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
        if node.attributes["insecure"] == "1"
            || node.attributes["insecure"]?.lowercased() == "true"
        {
            tls["insecure"] = true
        }
        if let alpn = node.attributes["alpn"], !alpn.isEmpty {
            tls["alpn"] = alpn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else if isV2 {
            // HY2 share-link default when ALPN absent (Hysteria URI / Core convention).
            tls["alpn"] = ["h3"]
        }
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
        // Prefer explicit up/down; do not invent 100/100 when absent.
        if let up = node.attributes["up"].flatMap(Int.init)
            ?? node.attributes["up_mbps"].flatMap(Int.init)
            ?? node.attributes["upmbps"].flatMap(Int.init)
        {
            outbound["up_mbps"] = up
        }
        if let down = node.attributes["down"].flatMap(Int.init)
            ?? node.attributes["down_mbps"].flatMap(Int.init)
            ?? node.attributes["downmbps"].flatMap(Int.init)
        {
            outbound["down_mbps"] = down
        }
        if let portsRaw = node.attributes["server_ports"], !portsRaw.isEmpty {
            outbound["server_ports"] = portsRaw
                .split(whereSeparator: { $0 == "," || $0 == ";" })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let hop = node.attributes["hop_interval"], !hop.isEmpty {
            outbound["hop_interval"] = hop
        }
        if let hopMax = node.attributes["hop_interval_max"], !hopMax.isEmpty {
            outbound["hop_interval_max"] = hopMax
        }
        if let obfs = node.attributes["obfs"] {
            if isV2 {
                var obfsObj: [String: Any] = [
                    "type": obfs,
                    "password": node.attributes["obfs_password"] ?? "",
                ]
                if let minP = node.attributes["obfs_min_packet_size"].flatMap(Int.init)
                    ?? node.attributes["min_packet_size"].flatMap(Int.init)
                {
                    obfsObj["min_packet_size"] = minP
                }
                if let maxP = node.attributes["obfs_max_packet_size"].flatMap(Int.init)
                    ?? node.attributes["max_packet_size"].flatMap(Int.init)
                {
                    obfsObj["max_packet_size"] = maxP
                }
                outbound["obfs"] = obfsObj
            } else {
                outbound["obfs"] = obfs
            }
        }
        return outbound
    }
}
