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
        "remark", "remarks", "ps", "name", "title", "fragment", "emoji",
        "flag", "country", "isp", "provider", "group", "category",
        "download", "upload", "total", "expire", "usage",
    ]

    /// Protocol/transport keys we already understand (lowercase).
    public static let knownProtocolKeys: Set<String> = [
        "type", "network", "security", "encryption", "flow", "sni", "host", "path",
        "fp", "fingerprint", "alpn", "pbk", "public-key", "public_key", "sid", "short-id", "short_id",
        "spx", "pqv", "allowinsecure", "insecure", "packetencoding", "packet_encoding",
        "servicename", "service_name", "serviceName", "mode", "headertype", "headerType",
        "seed", "authority", "quicsecurity", "key", "password", "uuid", "id", "aid", "scy",
        "method", "cipher", "plugin", "plugin-opts", "plugin_opts",
        "obfs", "obfs_password", "auth", "auth_str", "up", "down", "mtu",
        "username", "user", "pass", "transport", "multiplexing", "traffic_pattern",
        "server_ports", "congestion_control", "udp_relay_mode", "zero_rtt",
        "private_key", "peer_public_key", "public_key", "local_address", "preshared_key",
        "keepalive", "allowed_ips", "endpoint", "jc", "jmin", "jmax", "s1", "s2", "s3", "s4",
        "h1", "h2", "h3", "h4", "i1", "i2", "i3", "i4", "i5",
        "xraytag", "extra", "xmux", "scmaxeachpostbytes", "scminpostsintervalms",
        "sc_max_each_post_bytes", "sc_min_posts_interval_ms", "sc_max_concurrent_posts",
        "x_padding_bytes", "session", "seq", "uplink", "eh", "ed",
        "client-fingerprint", "servername", "skip-cert-verify", "udp", "tls",
        "grpc-service-name", "ws-opts.path", "reality-opts.public-key", "reality-opts.short-id",
        "net", "scy", "aid",
        // Structural / share-link / Clash keys mirrored onto NormalizedNode.attributes
        "server", "port", "address", "add", "v", "alterid", "alterId",
        "amnezia_version", "amnezia", "interface", "peer", "listen_port",
        "persistentkeepalive", "persistent_keepalive", "allowedips", "dns",
        "pre_shared_key", "preshared-key", "reserved", "workers",
        "flow", "packet_encoding", "packetencoding",
        "lowentropy", "low_entropy", "low-entropy", "multiplex",
        "server_address", "server_port", "serveraddress", "serverport",
        "profilename", "profile_name", "userdataencryption",
        "maxconcurrency", "maxconnections",
    ]

    public static func classify(key: String, value: String = "") -> CompatibilityFieldKind {
        let k = key.lowercased()
        if harmlessAllowlist.contains(k) { return .harmlessMetadata }
        if k.hasPrefix("x-") || k.hasPrefix("profile-") || k.hasPrefix("subscription-") {
            return .panelMetadata
        }
        // Xray stream/settings dumps: known leaves stay auditable; unknown nested knobs fail closed.
        if k.hasPrefix("stream.") || k.hasPrefix("settings.") {
            let leaf = String(k.split(separator: ".").last ?? Substring(k)).lowercased()
            if knownProtocolKeys.contains(leaf) || harmlessAllowlist.contains(leaf) {
                return .futureField
            }
            let knownDumpLeaves: Set<String> = [
                "network", "security", "servername", "fingerprint", "publickey", "shortid",
                "spiderx", "show", "allowinsecure", "alpn", "path", "host", "mode", "extra",
                "headers", "maxconcurrency", "maxconnections", "cmaxreuse",
                "hmaxrequesttimes", "hmaxreusabletimes", "hkeepaliveperiod",
                "scmaxeachpostbytes", "scminpostsintervalms", "scmaxconcurrentposts",
                "xpaddingbytes", "xmux", "vnext", "address", "port", "users", "id",
                "encryption", "flow", "email", "level",
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
        let criticalHints = ["enc", "crypt", "token", "secret", "reality", "xhttp", "awg", "obfs", "mux", "padding", "cookie", "rekey", "handshake"]
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
        allKeys: Set<String>,
        consumedKeys: Set<String>,
        ecosystem: String,
        protocolID: String
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
