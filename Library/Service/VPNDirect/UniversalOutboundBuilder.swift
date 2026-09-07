import Foundation

/// Builds sing-box outbound dictionaries from `NormalizedNode` fields.
///
/// Release invariant: an explicit connection-critical source value is either emitted with its
/// original semantics or the builder fails. It is never silently replaced with a convenient default.
public enum UniversalOutboundBuilder {
    public static func build(from node: NormalizedNode) throws -> [String: Any] {
        if node.outbound == nil || node.outbound?.isEmpty == true {
            let candidateKeys = Set(node.attributes.keys)
                .union(node.rawExtensions.keys)
                .filter { key in
                    let k = key.lowercased()
                    if k.hasPrefix("xray") { return false }
                    if k.hasPrefix("stream.") || k.hasPrefix("settings.") {
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

        // Temporary compatibility bridge. Remaining writers must be migrated because this bypasses
        // the typed builder path; until then preserve the exact already-mapped Core object.
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
            guard let built = HysteriaOutboundFactory.fromAttributes(node) else {
                throw VPNDirectCoreError.malformedConfig(component: "hysteria", detail: "Missing normalized Hysteria fields")
            }
            return built
        case .tuic:
            return try buildTUIC(node)
        case .anytls:
            return try buildAnyTLS(node)
        case .wireguard, .amneziawg:
            // The pinned Leadaxe Core registers WireGuard/AWG as top-level endpoints. Production
            // graph emission owns this path; returning the removed legacy outbound would be invalid.
            throw VPNDirectCoreError.unsupportedFeature(
                component: "wireguard",
                detail: "WireGuard/AmneziaWG must be emitted as a top-level endpoint by SingBoxGraphBuilder"
            )
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
            if node.protocolID.rawValue == "shadowtls" { return try buildShadowTLS(node) }
            if node.protocolID.rawValue == "naive" { return try buildNaive(node) }
            throw VPNDirectCoreError.unsupportedFeature(
                component: node.protocolID.rawValue,
                detail: "No outbound builder for protocol"
            )
        }
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
            "traffic_pattern": ["traffic_pattern", "traffic-pattern"],
            "udp_over_tcp": ["udp_over_tcp", "udp-over-tcp", "uot"],
            "packet_encoding": ["packet_encoding", "packet-encoding"],
            "private_key": ["private_key", "private-key", "privateKey"],
            "public_key": ["public_key", "public-key", "publicKey"],
        ]
        let keys = aliases[key] ?? [key, key.lowercased()]
        for k in keys {
            if let v = node.attributes[k] ?? node.attributes[k.lowercased()], !v.isEmpty { return v }
        }
        return nil
    }

    private static func boolAttr(_ node: NormalizedNode, _ key: String) throws -> Bool? {
        guard let raw = attr(node, key) else { return nil }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default:
            throw VPNDirectCoreError.malformedConfig(component: node.protocolID.rawValue, detail: "Invalid boolean \(key)=\(raw)")
        }
    }

    private static func intAttr(_ node: NormalizedNode, _ key: String) throws -> Int? {
        guard let raw = attr(node, key) else { return nil }
        guard let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw VPNDirectCoreError.malformedConfig(component: node.protocolID.rawValue, detail: "Invalid integer \(key)=\(raw)")
        }
        return value
    }

    private static func listAttr(_ node: NormalizedNode, _ key: String) -> [String]? {
        guard let raw = attr(node, key) else { return nil }
        let values = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }

    private static func jsonAttr(_ node: NormalizedNode, _ key: String) throws -> Any? {
        guard let raw = attr(node, key) else { return nil }
        guard let data = raw.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data)
        else {
            throw VPNDirectCoreError.malformedConfig(component: node.protocolID.rawValue, detail: "\(key) must be valid JSON")
        }
        return value
    }

    private static func tlsObject(from node: NormalizedNode, defaultSNI: String? = nil, forceEnabled: Bool = false) throws -> [String: Any]? {
        let securityRaw = (node.security?.rawValue ?? attr(node, "security") ?? "none").lowercased()
        let hasReality = securityRaw == "reality"
            || attr(node, "pbk") != nil
            || node.attributes.keys.contains(where: { $0.lowercased().hasPrefix("reality-opts") || $0.lowercased() == "public-key" })
        let enabled = forceEnabled || securityRaw == "tls" || hasReality || attr(node, "sni") != nil || attr(node, "alpn") != nil
        guard enabled else { return nil }

        var tls: [String: Any] = ["enabled": true]
        if let sni = attr(node, "sni") ?? attr(node, "peer") ?? defaultSNI, !sni.isEmpty { tls["server_name"] = sni }
        if let insecure = try boolAttr(node, "insecure") ?? boolAttr(node, "allowInsecure") { tls["insecure"] = insecure }
        if let alpn = listAttr(node, "alpn") { tls["alpn"] = alpn }
        if let value = attr(node, "min_version") { tls["min_version"] = value }
        if let value = attr(node, "max_version") { tls["max_version"] = value }
        if let values = listAttr(node, "cipher_suites") { tls["cipher_suites"] = values }
        if let values = listAttr(node, "curve_preferences") { tls["curve_preferences"] = values }
        if let timeout = attr(node, "handshake_timeout") { tls["handshake_timeout"] = timeout }
        if let fragment = try boolAttr(node, "fragment") { tls["fragment"] = fragment }
        if let delay = attr(node, "fragment_fallback_delay") { tls["fragment_fallback_delay"] = delay }
        if let record = try boolAttr(node, "record_fragment") { tls["record_fragment"] = record }

        if let fp = attr(node, "fp"), !fp.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": fp]
        }
        if hasReality {
            guard let pbk = attr(node, "pbk"), !pbk.isEmpty else {
                throw VPNDirectCoreError.malformedConfig(component: "reality", detail: "Missing public key")
            }
            var reality: [String: Any] = ["enabled": true, "public_key": pbk]
            if let sid = attr(node, "sid") { reality["short_id"] = sid }
            tls["reality"] = reality
        }
        return tls
    }

    private static func multiplexObject(from node: NormalizedNode) throws -> [String: Any]? {
        let explicitlyEnabled = try boolAttr(node, "multiplex_enabled") ?? boolAttr(node, "mux")
        let protocolName = attr(node, "multiplex_protocol") ?? attr(node, "mux_protocol")
        let hasFields = explicitlyEnabled != nil || protocolName != nil
            || attr(node, "max_connections") != nil || attr(node, "min_streams") != nil
            || attr(node, "max_streams") != nil || attr(node, "multiplex_padding") != nil
        guard hasFields else { return nil }

        var mux: [String: Any] = ["enabled": explicitlyEnabled ?? true]
        if let protocolName { mux["protocol"] = protocolName }
        if let value = try intAttr(node, "max_connections") { mux["max_connections"] = value }
        if let value = try intAttr(node, "min_streams") { mux["min_streams"] = value }
        if let value = try intAttr(node, "max_streams") { mux["max_streams"] = value }
        if let value = try boolAttr(node, "multiplex_padding") { mux["padding"] = value }
        return mux
    }

    private static func transportObject(from node: NormalizedNode) throws -> [String: Any]? {
        let explicit = node.transport?.rawValue ?? attr(node, "network") ?? attr(node, "net") ?? attr(node, "type")
        guard let explicit else { return nil }
        let t = explicit.lowercased()
        switch t {
        case "tcp", "raw":
            return nil
        case "ws", "websocket":
            var ws: [String: Any] = ["type": "ws"]
            if let path = attr(node, "path") { ws["path"] = path }
            var headers: [String: String] = [:]
            if let host = attr(node, "host") { headers["Host"] = host }
            if let rawHeaders = attr(node, "headers_json"),
               let data = rawHeaders.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            { headers.merge(parsed) { _, new in new } }
            if !headers.isEmpty { ws["headers"] = headers }
            if let value = try intAttr(node, "max_early_data") { ws["max_early_data"] = value }
            if let value = attr(node, "early_data_header_name") { ws["early_data_header_name"] = value }
            return ws
        case "grpc":
            var grpc: [String: Any] = ["type": "grpc"]
            if let service = attr(node, "service_name") ?? attr(node, "serviceName") ?? attr(node, "servicename") { grpc["service_name"] = service }
            if let value = attr(node, "idle_timeout") { grpc["idle_timeout"] = value }
            if let value = attr(node, "ping_timeout") { grpc["ping_timeout"] = value }
            if let value = try boolAttr(node, "permit_without_stream") { grpc["permit_without_stream"] = value }
            return grpc
        case "httpupgrade":
            var hu: [String: Any] = ["type": "httpupgrade"]
            if let path = attr(node, "path") { hu["path"] = path }
            if let host = attr(node, "host") { hu["host"] = host }
            if let rawHeaders = attr(node, "headers_json"),
               let data = rawHeaders.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            { hu["headers"] = parsed }
            return hu
        case "http", "h2":
            var http: [String: Any] = ["type": "http"]
            if let hosts = listAttr(node, "host") { http["host"] = hosts }
            if let path = attr(node, "path") { http["path"] = path }
            if let method = attr(node, "method") { http["method"] = method }
            if let rawHeaders = attr(node, "headers_json"),
               let data = rawHeaders.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            { http["headers"] = parsed }
            if let value = attr(node, "idle_timeout") { http["idle_timeout"] = value }
            if let value = attr(node, "ping_timeout") { http["ping_timeout"] = value }
            return http
        case "xhttp", "splithttp":
            guard VPNDirectCoreCapabilities.current.supportsXHTTP else {
                throw VPNDirectCoreError.unsupportedFeature(component: "xhttp", detail: "Current Libbox build lacks native xhttp transport")
            }
            var xhttp: [String: Any] = ["type": "xhttp"]
            if let hosts = listAttr(node, "host") { xhttp["host"] = hosts }
            if let path = attr(node, "path") { xhttp["path"] = path }
            if let mode = attr(node, "mode") { xhttp["mode"] = mode }
            if let rawHeaders = attr(node, "headers_json"),
               let data = rawHeaders.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            { xhttp["headers"] = parsed }

            // Pinned Leadaxe/sing-box-lx v1.14.0-lx.35 models these as strings because they
            // accept both a single value and Xray-compatible ranges such as `1000-2000`.
            for key in [
                "x_padding_bytes",
                "sc_max_each_post_bytes",
                "sc_min_posts_interval_ms",
                "sc_stream_up_server_secs",
                "xmux_max_concurrency",
                "xmux_h_max_request_times",
                "xmux_h_max_reusable_secs",
                "session_placement",
                "session_key",
                "seq_placement",
                "seq_key",
                "session_table",
                "session_length",
                "uplink_data_placement",
                "uplink_data_key",
                "uplink_chunk_size",
                "uplink_http_method",
                "x_padding_key",
                "x_padding_header",
                "x_padding_placement",
                "x_padding_method",
            ] {
                if let value = attr(node, key) { xhttp[key] = value }
            }

            // These pinned fields are true integer fields, not range strings.
            for key in [
                "sc_max_buffered_posts",
                "xmux_max_connections",
                "xmux_c_max_reuse_times",
                "xmux_h_keep_alive_period",
            ] {
                if let value = try intAttr(node, key) { xhttp[key] = value }
            }

            for key in ["no_grpc_header", "xmux_no_grpc_header", "x_padding_obfs_mode"] {
                if let value = try boolAttr(node, key) { xhttp[key] = value }
            }

            // `download_settings` is `any` in the pinned Core. Preserve a structured JSON value;
            // never stringify it and never emit the Xray-only wrapper key `extra` to sing-box.
            if let value = try jsonAttr(node, "download_settings_json") ?? jsonAttr(node, "download_settings") {
                xhttp["download_settings"] = value
            }
            return xhttp
        default:
            throw VPNDirectCoreError.unsupportedFeature(component: "transport", detail: "Unsupported explicit transport: \(explicit)")
        }
    }

    // MARK: - Protocol builders

    private static func buildVLESS(_ node: NormalizedNode) throws -> [String: Any] {
        guard let uuid = node.uuid ?? attr(node, "uuid"), !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "vless", detail: "Missing uuid")
        }
        var outbound: [String: Any] = ["type": "vless", "tag": node.name, "server": node.server, "server_port": node.port, "uuid": uuid]
        if let flow = attr(node, "flow") { outbound["flow"] = flow }
        if let network = attr(node, "outbound_network") { outbound["network"] = network }
        if let tls = try tlsObject(from: node, defaultSNI: nil) { outbound["tls"] = tls }
        if let transport = try transportObject(from: node) { outbound["transport"] = transport }
        if let encryption = attr(node, "encryption") {
            if encryption.lowercased() != "none" && !VPNDirectCoreCapabilities.current.supportsVLESSEncryption {
                throw VPNDirectCoreError.unsupportedFeature(component: "vless.encryption", detail: "Current Libbox build lacks VLESS encryption/PQ support")
            }
            outbound["encryption"] = encryption
        }
        if let packet = attr(node, "packet_encoding") { outbound["packet_encoding"] = packet }
        if let mux = try multiplexObject(from: node) { outbound["multiplex"] = mux }
        return outbound
    }

    private static func buildVMess(_ node: NormalizedNode) throws -> [String: Any] {
        guard let uuid = node.uuid ?? attr(node, "id") ?? attr(node, "uuid"), !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "vmess", detail: "Missing id")
        }
        var outbound: [String: Any] = ["type": "vmess", "tag": node.name, "server": node.server, "server_port": node.port, "uuid": uuid]
        if let security = attr(node, "scy") ?? attr(node, "security") { outbound["security"] = security }
        if let alterID = try intAttr(node, "aid") { outbound["alter_id"] = alterID }
        if let value = try boolAttr(node, "global_padding") { outbound["global_padding"] = value }
        if let value = try boolAttr(node, "authenticated_length") { outbound["authenticated_length"] = value }
        if let network = attr(node, "outbound_network") { outbound["network"] = network }
        if let tls = try tlsObject(from: node, defaultSNI: nil) { outbound["tls"] = tls }
        if let transport = try transportObject(from: node) { outbound["transport"] = transport }
        if let packet = attr(node, "packet_encoding") { outbound["packet_encoding"] = packet }
        if let mux = try multiplexObject(from: node) { outbound["multiplex"] = mux }
        return outbound
    }

    private static func buildTrojan(_ node: NormalizedNode) throws -> [String: Any] {
        guard let password = attr(node, "password") ?? node.uuid, !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "trojan", detail: "Missing password")
        }
        var outbound: [String: Any] = ["type": "trojan", "tag": node.name, "server": node.server, "server_port": node.port, "password": password]
        if let network = attr(node, "outbound_network") { outbound["network"] = network }
        if let tls = try tlsObject(from: node, defaultSNI: nil, forceEnabled: true) { outbound["tls"] = tls }
        if let transport = try transportObject(from: node) { outbound["transport"] = transport }
        if let mux = try multiplexObject(from: node) { outbound["multiplex"] = mux }
        return outbound
    }

    private static func buildShadowsocks(_ node: NormalizedNode) throws -> [String: Any] {
        guard let method = attr(node, "method") ?? attr(node, "cipher"), !method.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Missing method")
        }
        guard let password = attr(node, "password"), !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "shadowsocks", detail: "Missing password")
        }
        var outbound: [String: Any] = ["type": "shadowsocks", "tag": node.name, "server": node.server, "server_port": node.port, "method": method, "password": password]
        if let plugin = attr(node, "plugin") {
            outbound["plugin"] = plugin
            if let opts = attr(node, "plugin_opts") { outbound["plugin_opts"] = opts }
        }
        if let network = attr(node, "outbound_network") { outbound["network"] = network }
        if let uot = try boolAttr(node, "udp_over_tcp") { outbound["udp_over_tcp"] = uot }
        if let mux = try multiplexObject(from: node) { outbound["multiplex"] = mux }
        return outbound
    }

    private static func buildTUIC(_ node: NormalizedNode) throws -> [String: Any] {
        guard let uuid = node.uuid ?? attr(node, "uuid"), !uuid.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "tuic", detail: "Missing uuid")
        }
        guard let password = attr(node, "password"), !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "tuic", detail: "Missing password")
        }
        var outbound: [String: Any] = ["type": "tuic", "tag": node.name, "server": node.server, "server_port": node.port, "uuid": uuid, "password": password]
        if let cc = attr(node, "congestion_control") ?? attr(node, "congestion") { outbound["congestion_control"] = cc }
        if let value = attr(node, "udp_relay_mode") { outbound["udp_relay_mode"] = value }
        if let value = try boolAttr(node, "udp_over_stream") { outbound["udp_over_stream"] = value }
        if let value = try boolAttr(node, "zero_rtt_handshake") { outbound["zero_rtt_handshake"] = value }
        if let value = attr(node, "heartbeat") { outbound["heartbeat"] = value }
        if let network = attr(node, "outbound_network") { outbound["network"] = network }
        outbound["tls"] = try tlsObject(from: node, defaultSNI: nil, forceEnabled: true)
        return outbound
    }

    private static func buildAnyTLS(_ node: NormalizedNode) throws -> [String: Any] {
        guard let password = attr(node, "password"), !password.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "anytls", detail: "Missing password")
        }
        var outbound: [String: Any] = ["type": "anytls", "tag": node.name, "server": node.server, "server_port": node.port, "password": password]
        if let value = attr(node, "idle_session_check_interval") { outbound["idle_session_check_interval"] = value }
        if let value = attr(node, "idle_session_timeout") { outbound["idle_session_timeout"] = value }
        if let value = try intAttr(node, "min_idle_session") { outbound["min_idle_session"] = value }
        outbound["tls"] = try tlsObject(from: node, defaultSNI: nil, forceEnabled: true)
        return outbound
    }

    private static func buildSOCKS(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = ["type": "socks", "tag": node.name, "server": node.server, "server_port": node.port]
        if let version = attr(node, "version") { outbound["version"] = version }
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let network = attr(node, "outbound_network") { outbound["network"] = network }
        if let uot = try boolAttr(node, "udp_over_tcp") { outbound["udp_over_tcp"] = uot }
        return outbound
    }

    private static func buildHTTP(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = ["type": "http", "tag": node.name, "server": node.server, "server_port": node.port]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let path = attr(node, "path") { outbound["path"] = path }
        if let rawHeaders = attr(node, "headers_json"),
           let data = rawHeaders.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        { outbound["headers"] = parsed }
        if let tls = try tlsObject(from: node, defaultSNI: nil) { outbound["tls"] = tls }
        return outbound
    }

    private static func buildSSH(_ node: NormalizedNode) throws -> [String: Any] {
        guard let user = attr(node, "user") ?? attr(node, "username"), !user.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "ssh", detail: "Missing user; VPN Direct does not invent root")
        }
        var outbound: [String: Any] = ["type": "ssh", "tag": node.name, "server": node.server, "server_port": node.port, "user": user]
        if let password = attr(node, "password") { outbound["password"] = password }
        if let key = attr(node, "private_key") { outbound["private_key"] = key }
        if let path = attr(node, "private_key_path") { outbound["private_key_path"] = path }
        if let value = attr(node, "private_key_passphrase") { outbound["private_key_passphrase"] = value }
        if let values = listAttr(node, "host_key") { outbound["host_key"] = values }
        if let values = listAttr(node, "host_key_algorithms") { outbound["host_key_algorithms"] = values }
        if let value = attr(node, "client_version") { outbound["client_version"] = value }
        if let values = listAttr(node, "cipher") { outbound["cipher"] = values }
        if let values = listAttr(node, "mac") { outbound["mac"] = values }
        if let values = listAttr(node, "kex_algorithm") { outbound["kex_algorithm"] = values }
        return outbound
    }

    private static func buildShadowTLS(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = ["type": "shadowtls", "tag": node.name, "server": node.server, "server_port": node.port]
        if let version = try intAttr(node, "version") { outbound["version"] = version }
        if let password = attr(node, "password") { outbound["password"] = password }
        outbound["tls"] = try tlsObject(from: node, defaultSNI: nil, forceEnabled: true)
        return outbound
    }

    private static func buildNaive(_ node: NormalizedNode) throws -> [String: Any] {
        var outbound: [String: Any] = ["type": "naive", "tag": node.name, "server": node.server, "server_port": node.port]
        if let user = attr(node, "username") { outbound["username"] = user }
        if let pass = attr(node, "password") { outbound["password"] = pass }
        if let value = try intAttr(node, "insecure_concurrency") { outbound["insecure_concurrency"] = value }
        if let value = try intAttr(node, "stream_receive_window") { outbound["stream_receive_window"] = value }
        if let value = try boolAttr(node, "udp_over_tcp") { outbound["udp_over_tcp"] = value }
        if let value = try boolAttr(node, "quic") { outbound["quic"] = value }
        if let value = attr(node, "quic_congestion_control") { outbound["quic_congestion_control"] = value }
        if let value = try intAttr(node, "quic_session_receive_window") { outbound["quic_session_receive_window"] = value }
        if let rawHeaders = attr(node, "extra_headers_json"),
           let data = rawHeaders.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        { outbound["extra_headers"] = parsed }
        if let tls = try tlsObject(from: node, defaultSNI: nil, forceEnabled: true) { outbound["tls"] = tls }
        return outbound
    }

    private static func buildMasque(_ node: NormalizedNode) throws -> [String: Any] {
        guard VPNDirectCoreCapabilities.current.supportsMasqueConnectIP else {
            throw VPNDirectCoreError.unsupportedFeature(component: "masque", detail: "Current Libbox build lacks MASQUE CONNECT-IP")
        }

        let profile = (attr(node, "profile") ?? "cloudflare").lowercased()
        guard profile == "cloudflare" || profile == "standard" else {
            throw VPNDirectCoreError.unsupportedFeature(component: "masque.profile", detail: "Unsupported MASQUE profile: \(profile)")
        }
        if let vhttp = attr(node, "vhttp") {
            guard ["h3", "h2", "auto"].contains(vhttp.lowercased()) else {
                throw VPNDirectCoreError.malformedConfig(component: "masque", detail: "vhttp must be h3, h2, or auto")
            }
            if profile == "standard" && vhttp.lowercased() == "h2" {
                throw VPNDirectCoreError.unsupportedFeature(component: "masque.standard", detail: "Pinned Core standard profile has no h2 leg")
            }
        }

        var outbound: [String: Any] = ["type": "masque", "tag": node.name, "server": node.server, "server_port": node.port, "profile": profile]
        if let vhttp = attr(node, "vhttp") { outbound["vhttp"] = vhttp.lowercased() }
        if let uri = attr(node, "uri") { outbound["uri"] = uri }
        if let mtu = try intAttr(node, "mtu") { outbound["mtu"] = mtu }
        if let timeout = attr(node, "idle_timeout") { outbound["idle_timeout"] = timeout }
        if let keepalive = attr(node, "keep_alive_period") { outbound["keep_alive_period"] = keepalive }
        if let networks = listAttr(node, "network_list") { outbound["network_list"] = networks }

        if profile == "cloudflare" {
            guard let privateKey = attr(node, "private_key"), !privateKey.isEmpty,
                  let publicKey = attr(node, "public_key"), !publicKey.isEmpty
            else {
                throw VPNDirectCoreError.malformedConfig(component: "masque.cloudflare", detail: "Missing WARP private/public key")
            }
            guard attr(node, "ip") != nil || attr(node, "ipv6") != nil else {
                throw VPNDirectCoreError.malformedConfig(component: "masque.cloudflare", detail: "At least one WARP tunnel IP is required")
            }
            outbound["private_key"] = privateKey
            outbound["public_key"] = publicKey
            if let ip = attr(node, "ip") { outbound["ip"] = ip }
            if let ipv6 = attr(node, "ipv6") { outbound["ipv6"] = ipv6 }
        }

        if let tls = try tlsObject(from: node, defaultSNI: nil, forceEnabled: true) { outbound["tls"] = tls }
        return outbound
    }

    private static func buildMieru(_ node: NormalizedNode) throws -> [String: Any] {
        guard VPNDirectCoreCapabilities.current.supportsMieru else {
            throw VPNDirectCoreError.unsupportedFeature(component: "mieru", detail: "Mieru runtime not registered in this Libbox build")
        }
        guard let transport = attr(node, "transport")?.uppercased(), transport == "TCP" || transport == "UDP" else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "transport must be explicitly TCP or UDP")
        }
        guard let user = attr(node, "username"), !user.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Missing username")
        }
        guard let pass = attr(node, "password"), !pass.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Missing password")
        }
        guard node.port > 0 || attr(node, "server_ports") != nil else {
            throw VPNDirectCoreError.malformedConfig(component: "mieru", detail: "Either server_port or server_ports is required")
        }

        var outbound: [String: Any] = ["type": "mieru", "tag": node.name, "server": node.server, "transport": transport, "username": user, "password": pass]
        if node.port > 0 { outbound["server_port"] = node.port }
        if let ports = listAttr(node, "server_ports") { outbound["server_ports"] = ports }
        if let multiplexing = attr(node, "multiplexing") { outbound["multiplexing"] = multiplexing }
        if let pattern = attr(node, "traffic_pattern") { outbound["traffic_pattern"] = pattern }
        return outbound
    }
}

extension HysteriaOutboundFactory {
    static func fromAttributes(_ node: NormalizedNode) -> [String: Any]? {
        let auth = node.attributes["auth"] ?? node.attributes["password"] ?? node.uuid
        guard let auth, !auth.isEmpty, !node.server.isEmpty, node.port > 0 else { return nil }
        let isV2 = node.protocolID == .hysteria2
        var tls: [String: Any] = ["enabled": true]
        if let sni = node.attributes["sni"], !sni.isEmpty { tls["server_name"] = sni }
        if let raw = node.attributes["insecure"]?.lowercased() {
            if ["1", "true"].contains(raw) { tls["insecure"] = true }
            if ["0", "false"].contains(raw) { tls["insecure"] = false }
        }
        if let alpn = node.attributes["alpn"] {
            tls["alpn"] = alpn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }

        var outbound: [String: Any] = ["type": isV2 ? "hysteria2" : "hysteria", "tag": node.name, "server": node.server, "server_port": node.port, "tls": tls]
        if isV2 { outbound["password"] = auth } else { outbound["auth_str"] = auth }
        if let up = node.attributes["up"]?.trimmingCharacters(in: .whitespaces), let value = Int(up) { outbound["up_mbps"] = value }
        if let down = node.attributes["down"]?.trimmingCharacters(in: .whitespaces), let value = Int(down) { outbound["down_mbps"] = value }
        if let serverPorts = node.attributes["server_ports"] {
            outbound["server_ports"] = serverPorts.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        if let hop = node.attributes["hop_interval"] { outbound["hop_interval"] = hop }
        if let hopMax = node.attributes["hop_interval_max"] { outbound["hop_interval_max"] = hopMax }
        if let network = node.attributes["outbound_network"] { outbound["network"] = network }
        if let obfs = node.attributes["obfs"] {
            if isV2 {
                var object: [String: Any] = ["type": obfs]
                if let password = node.attributes["obfs_password"], !password.isEmpty { object["password"] = password }
                if let min = node.attributes["obfs_min_packet_size"].flatMap(Int.init) { object["min_packet_size"] = min }
                if let max = node.attributes["obfs_max_packet_size"].flatMap(Int.init) { object["max_packet_size"] = max }
                outbound["obfs"] = object
            } else {
                outbound["obfs"] = obfs
            }
        }
        if let profile = node.attributes["bbr_profile"] { outbound["bbr_profile"] = profile }
        if let raw = node.attributes["brutal_debug"]?.lowercased(), ["1", "true", "0", "false"].contains(raw) {
            outbound["brutal_debug"] = ["1", "true"].contains(raw)
        }
        if let raw = node.attributes["disable_chrome_parrot"]?.lowercased(), ["1", "true", "0", "false"].contains(raw) {
            outbound["disable_chrome_parrot"] = ["1", "true"].contains(raw)
        }
        return outbound
    }
}
