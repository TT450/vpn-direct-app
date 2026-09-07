import Foundation

/// Classification of imported fields that do not map 1:1 to sing-box today.
public enum CompatibilityFieldKind: String, Sendable {
    case harmlessMetadata
    case panelMetadata
    case protocolExtension
    case futureField
    /// Must not be silently dropped — fail closed if builder cannot honor it.
    case connectionCritical
}

/// Decides whether an unknown key may be ignored, stored, or must fail closed.
public enum CompatibilityFieldPolicy {
    /// Keys that are never connection-critical when unseen by the builder.
    public static let harmlessAllowlist: Set<String> = [
        "remark", "remarks", "ps", "name", "title", "emoji",
        "flag", "country", "isp", "provider", "group", "category",
        "download", "upload", "total", "expire", "usage",
        // Derived display/debug counters. Runtime WireGuard emission uses the typed
        // `wireguardEndpoint` model; these counters never carry connection semantics.
        "peer_count", "address_count",
    ]

    /// Protocol/transport keys the production builder actually consumes (lowercase).
    ///
    /// IMPORTANT: being present here is a claim that the parser/normalized model/builder chain
    /// has a real consumer. Never add a key merely to silence fail-closed diagnostics.
    public static let knownProtocolKeys: Set<String> = [
        // Common endpoint/protocol identity.
        "type", "server", "port", "address", "add", "server_address", "server_port",
        "serveraddress", "serverport", "network", "net", "outbound_network",
        "security", "uuid", "id", "password", "pass", "username", "user",

        // VLESS / VMess / Trojan / Shadowsocks.
        "encryption", "flow", "packet_encoding", "packetencoding", "aid", "alterid", "scy",
        "global_padding", "authenticated_length", "method", "cipher", "plugin", "plugin-opts", "plugin_opts",
        "udp_over_tcp", "udp-over-tcp", "uot",

        // TLS / Reality / uTLS. `fragment` is intentionally NOT harmless metadata.
        "sni", "servername", "server_name", "peer", "fp", "fingerprint", "client-fingerprint", "client_fingerprint",
        "alpn", "pbk", "public-key", "public_key", "sid", "short-id", "short_id",
        "allowinsecure", "insecure", "min_version", "max_version", "cipher_suites", "curve_preferences",
        "handshake_timeout", "fragment", "fragment_fallback_delay", "record_fragment",

        // Generic sing-box multiplex.
        "multiplex_enabled", "mux", "multiplex_protocol", "mux_protocol",
        "max_connections", "min_streams", "max_streams", "multiplex_padding",

        // V2Ray transports.
        "host", "path", "headers_json", "max_early_data", "early_data_header_name",
        "servicename", "service_name", "idle_timeout", "ping_timeout", "permit_without_stream",

        // Pinned sing-box-lx v1.14.0-lx.35 XHTTP fields.
        "mode", "x_padding_bytes", "sc_max_each_post_bytes", "sc_min_posts_interval_ms",
        "sc_max_buffered_posts", "sc_stream_up_server_secs",
        "xmux_max_concurrency", "xmux_max_connections", "xmux_c_max_reuse_times",
        "xmux_h_max_request_times", "xmux_h_max_reusable_secs", "xmux_h_keep_alive_period",
        "no_grpc_header", "xmux_no_grpc_header",
        "session_placement", "session_key", "seq_placement", "seq_key",
        "session_table", "session_length", "uplink_data_placement", "uplink_data_key",
        "uplink_chunk_size", "uplink_http_method", "x_padding_obfs_mode",
        "x_padding_key", "x_padding_header", "x_padding_placement", "x_padding_method",
        "download_settings", "download_settings_json",

        // Hysteria / Hysteria2.
        "auth", "auth_str", "up", "down", "server_ports", "hop_interval", "hop_interval_max",
        "obfs", "obfs_password", "obfs_min_packet_size", "obfs_max_packet_size",
        "bbr_profile", "brutal_debug", "disable_chrome_parrot",

        // TUIC.
        "congestion_control", "congestion", "udp_relay_mode", "udp_over_stream",
        "zero_rtt_handshake", "heartbeat",

        // AnyTLS.
        "idle_session_check_interval", "idle_session_timeout", "min_idle_session",

        // SOCKS / HTTP / SSH / ShadowTLS / Naive.
        "version", "private_key", "private_key_path", "private_key_passphrase",
        "host_key", "host_key_algorithms", "client_version", "mac", "kex_algorithm",
        "insecure_concurrency", "stream_receive_window", "quic", "quic_congestion_control",
        "quic_session_receive_window", "extra_headers_json",

        // MASQUE / WARP-via-MASQUE.
        "profile", "vhttp", "uri", "mtu", "keep_alive_period", "network_list",
        "ip", "ipv6",

        // Mieru.
        "transport", "multiplexing", "traffic_pattern",

        // WireGuard / AmneziaWG source aliases retained while runtime uses the typed endpoint model.
        "private-key", "privatekey", "peer_public_key", "publickey", "local_address", "preshared_key",
        "keepalive", "allowed_ips", "endpoint", "jc", "jmin", "jmax", "s1", "s2", "s3", "s4",
        "h1", "h2", "h3", "h4", "i1", "i2", "i3", "i4", "i5",
        "amnezia_version", "amnezia", "interface", "listen_port", "persistentkeepalive",
        "persistent_keepalive", "allowedips", "dns", "pre_shared_key", "preshared-key", "reserved", "workers",

        // Provenance/structural aliases consumed by parsers/builders.
        "xraytag", "v", "alterid", "profilename", "profile_name", "userdataencryption",
        "lowentropy", "low_entropy", "low-entropy", "multiplex",
    ]

    public static func classify(key: String, value: String = "") -> CompatibilityFieldKind {
        let k = key.lowercased()
        if harmlessAllowlist.contains(k) { return .harmlessMetadata }
        if k.hasPrefix("x-") || k.hasPrefix("profile-") || k.hasPrefix("subscription-") {
            return .panelMetadata
        }

        // Xray WS/HTTPUpgrade header dictionaries are serialized losslessly into `headers_json`
        // and emitted as the transport `headers` object. Their flattened diagnostic copies therefore
        // are not independent unconsumed fields. XHTTP is deliberately excluded until its arbitrary
        // header dictionary has the same exact source→normalized→builder coverage.
        if k.hasPrefix("stream.wssettings.headers.")
            || k.hasPrefix("stream.httpupgradesettings.headers.")
        {
            return .protocolExtension
        }

        // Xray stream/settings dumps: known leaves stay auditable; unknown nested knobs fail closed.
        if k.hasPrefix("stream.") || k.hasPrefix("settings.") {
            let leaf = String(k.split(separator: ".").last ?? Substring(k)).lowercased()
            if knownProtocolKeys.contains(leaf) || harmlessAllowlist.contains(leaf) {
                return .futureField
            }
            let knownDumpLeaves: Set<String> = [
                "network", "security", "servername", "fingerprint", "publickey", "shortid",
                "allowinsecure", "alpn", "path", "host", "mode", "headers",
                "xpaddingbytes", "scmaxeachpostbytes", "scminpostsintervalms", "scmaxbufferedposts",
                "scstreamupserversecs", "sessionplacement", "sessionkey", "seqplacement", "seqkey",
                "sessiontable", "sessionlength", "uplinkdataplacement", "uplinkdatakey",
                "uplinkchunksize", "uplinkhttpmethod", "xpaddinobfsmode", "xpaddingkey",
                "xpaddingheader", "xpaddingplacement", "xpaddingmethod", "nogrpcheader",
                "downloadsettings", "xmux", "maxconcurrency", "maxconnections", "cmaxreusetimes",
                "hmaxrequesttimes", "hmaxreusablesecs", "hkeepaliveperiod",
                "vnext", "address", "port", "users", "id", "encryption", "flow", "email", "level",
            ]
            if knownDumpLeaves.contains(leaf) { return .futureField }
            return .connectionCritical
        }
        if knownProtocolKeys.contains(k) { return .protocolExtension }

        // Nested Clash dotted keys we flattened intentionally.
        if k.contains("opts.") || k.hasPrefix("ws-opts") || k.hasPrefix("grpc-opts")
            || k.hasPrefix("reality-opts") || k.hasPrefix("plugin-opts") || k.hasPrefix("headers.")
        {
            return .protocolExtension
        }

        // Heuristic: keys that look like handshake knobs are critical until proven otherwise.
        let criticalHints = [
            "enc", "crypt", "token", "secret", "reality", "xhttp", "awg", "obfs", "mux",
            "padding", "cookie", "rekey", "handshake", "session", "uplink", "downloadsettings",
        ]
        if criticalHints.contains(where: { k.contains($0) }) {
            return .connectionCritical
        }
        // Bare "key" / "_key" suffix often means crypto material.
        if k == "key" || k.hasSuffix("_key") || k.hasSuffix("-key") {
            return .connectionCritical
        }
        if value.count > 256 { return .futureField }
        return .connectionCritical
    }

    /// Throws if any unknown key is connection-critical and not already consumed by the builder.
    public static func assertNoCriticalUnknowns(
        allKeys: Set<String>, consumedKeys: Set<String>, ecosystem: String, protocolID: String
    ) throws {
        for key in allKeys {
            let lower = key.lowercased()
            if consumedKeys.contains(lower) || consumedKeys.contains(key) { continue }
            if knownProtocolKeys.contains(lower) { continue }
            switch classify(key: key) {
            case .harmlessMetadata, .panelMetadata, .futureField, .protocolExtension:
                continue
            case .connectionCritical:
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "\(ecosystem).\(protocolID)",
                    detail: "unsupported option field=\(key) (connection-critical unknown; refusing silent drop)"
                )
            }
        }
    }
}
