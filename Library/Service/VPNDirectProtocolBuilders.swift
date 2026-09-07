import Foundation

/// AmneziaWG / WireGuard endpoint options for VPN Direct Core.
/// Versions are strings ("2", "3.0", "3.1") — not a closed enum — so future AWG releases do not require model rewrites.
public struct AmneziaWGEndpointOptions: Equatable, Sendable {
    public var privateKey: String
    public var address: [String]
    public var peers: [Peer]
    public var mtu: Int?
    public var amneziaVersion: String

    // Classic AWG obfuscation
    public var jc: Int?
    public var jmin: Int?
    public var jmax: Int?
    public var s1: Int?
    public var s2: Int?
    public var s3: Int?
    public var s4: Int?
    public var h1: String?
    public var h2: String?
    public var h3: String?
    public var h4: String?
    public var i1: String?
    public var i2: String?
    public var i3: String?
    public var i4: String?
    public var i5: String?

    // Masquerade sugar (WireSock-style)
    public var id: String?
    public var ip: String?
    public var ib: String?

    // AWG 3.x
    public var headerProtectionKey: String?
    public var contentPaddingAddition: String?
    public var randomTrailers: Bool?
    public var disableCookies: Bool?
    public var rekeyAfterTime: String?
    public var rekeyTimeout: String?
    public var rejectAfterTime: String?
    public var keepaliveTimeout: String?
    public var maxHandshakeAttempts: String?
    public var persistentKeepaliveInterval: String?

    public struct Peer: Equatable, Sendable {
        public var publicKey: String
        public var preSharedKey: String?
        public var allowedIPs: [String]
        public var endpoint: String?
        public var persistentKeepaliveInterval: Int?

        public init(
            publicKey: String,
            preSharedKey: String? = nil,
            allowedIPs: [String] = ["0.0.0.0/0", "::/0"],
            endpoint: String? = nil,
            persistentKeepaliveInterval: Int? = nil
        ) {
            self.publicKey = publicKey
            self.preSharedKey = preSharedKey
            self.allowedIPs = allowedIPs
            self.endpoint = endpoint
            self.persistentKeepaliveInterval = persistentKeepaliveInterval
        }
    }

    public init(
        privateKey: String,
        address: [String],
        peers: [Peer],
        mtu: Int? = nil,
        amneziaVersion: String = "2"
    ) {
        self.privateKey = privateKey
        self.address = address
        self.peers = peers
        self.mtu = mtu
        self.amneziaVersion = amneziaVersion
    }

    /// True only when no Amnezia-specific fields are set (plain WireGuard).
    public var hasNoObfuscation: Bool {
        jc == nil && jmin == nil && jmax == nil
            && s1 == nil && s2 == nil && s3 == nil && s4 == nil
            && h1 == nil && h2 == nil && h3 == nil && h4 == nil
            && i1 == nil && i2 == nil && i3 == nil && i4 == nil && i5 == nil
            && id == nil && ip == nil && ib == nil
            && headerProtectionKey == nil
            && contentPaddingAddition == nil
            && randomTrailers == nil
            && disableCookies == nil
            && rekeyAfterTime == nil
            && rekeyTimeout == nil
            && rejectAfterTime == nil
            && keepaliveTimeout == nil
            && maxHandshakeAttempts == nil
            && persistentKeepaliveInterval == nil
    }

    /// Infer AWG version from fields. Returns nil for plain WireGuard.
    /// Forced override wins when provided; ambiguous AWG claim without fields fails closed.
    public static func inferAmneziaVersion(
        from options: AmneziaWGEndpointOptions,
        forced: String? = nil,
        claimedAWG: Bool = false
    ) throws -> String? {
        if let forced, !forced.isEmpty {
            return forced
        }
        if options.hasNoObfuscation {
            if claimedAWG {
                throw VPNDirectCoreError.malformedConfig(
                    component: "amneziawg",
                    detail: "AWG claimed but no Amnezia fields present; refusing invented version"
                )
            }
            return nil
        }
        if options.randomTrailers == true || options.disableCookies == true {
            return "3.1"
        }
        if options.headerProtectionKey != nil
            || options.contentPaddingAddition != nil
            || options.rekeyAfterTime != nil
            || options.rekeyTimeout != nil
            || options.rejectAfterTime != nil
            || options.keepaliveTimeout != nil
            || options.maxHandshakeAttempts != nil
        {
            return "3.0"
        }
        // Classic junk / magic headers / CPS / masquerade sugar → AWG 2
        return "2"
    }

    /// Build options from flat share-link / Clash attributes (single peer).
    public static func fromFlatAttributes(
        privateKey: String,
        peerPublicKey: String,
        localAddress: [String],
        peerEndpoint: String,
        preSharedKey: String? = nil,
        mtu: Int? = nil,
        attributes: [String: String],
        forcedVersion: String? = nil,
        claimedAWG: Bool = false
    ) throws -> AmneziaWGEndpointOptions {
        var options = AmneziaWGEndpointOptions(
            privateKey: privateKey,
            address: localAddress.isEmpty ? ["10.0.0.2/32"] : localAddress,
            peers: [
                Peer(
                    publicKey: peerPublicKey,
                    preSharedKey: preSharedKey,
                    allowedIPs: Self.parseAllowedIPs(attributes["allowed_ips"] ?? attributes["allowedips"]),
                    endpoint: peerEndpoint,
                    persistentKeepaliveInterval: (attributes["persistent_keepalive"] ?? attributes["keepalive"])
                        .flatMap(Int.init)
                ),
            ],
            mtu: mtu,
            amneziaVersion: forcedVersion ?? "2"
        )
        options.jc = attributes["jc"].flatMap(Int.init)
        options.jmin = attributes["jmin"].flatMap(Int.init)
        options.jmax = attributes["jmax"].flatMap(Int.init)
        options.s1 = attributes["s1"].flatMap(Int.init)
        options.s2 = attributes["s2"].flatMap(Int.init)
        options.s3 = attributes["s3"].flatMap(Int.init)
        options.s4 = attributes["s4"].flatMap(Int.init)
        options.h1 = attributes["h1"]
        options.h2 = attributes["h2"]
        options.h3 = attributes["h3"]
        options.h4 = attributes["h4"]
        options.i1 = attributes["i1"]
        options.i2 = attributes["i2"]
        options.i3 = attributes["i3"]
        options.i4 = attributes["i4"]
        options.i5 = attributes["i5"]
        // Masquerade sugar — never confuse with WG interface address (`ip` / `local_address`).
        options.id = attributes["id"] ?? attributes["awg_id"]
        options.ip = attributes["awg_ip"] ?? attributes["masquerade_ip"]
        options.ib = attributes["ib"] ?? attributes["awg_ib"]
        options.headerProtectionKey = attributes["header_protection_key"] ?? attributes["headerprotectionkey"]
        options.contentPaddingAddition = attributes["content_padding_addition"] ?? attributes["contentpaddingaddition"]
        if let rt = attributes["random_trailers"] ?? attributes["randomtrailers"] {
            options.randomTrailers = (rt == "true" || rt == "1")
        }
        if let dc = attributes["disable_cookies"] ?? attributes["disablecookies"] {
            options.disableCookies = (dc == "true" || dc == "1")
        }
        options.rekeyAfterTime = attributes["rekey_after_time"] ?? attributes["rekeyaftertime"]
        options.rekeyTimeout = attributes["rekey_timeout"] ?? attributes["rekeytimeout"]
        options.rejectAfterTime = attributes["reject_after_time"] ?? attributes["rejectaftertime"]
        options.keepaliveTimeout = attributes["keepalive_timeout"] ?? attributes["keepalivetimeout"]
        options.maxHandshakeAttempts = attributes["max_handshake_attempts"] ?? attributes["maxhandshakeattempts"]
        options.persistentKeepaliveInterval = attributes["persistent_keepalive_interval"]
            ?? attributes["persistentkeepaliveinterval"]
        let version = try inferAmneziaVersion(from: options, forced: forcedVersion, claimedAWG: claimedAWG)
        options.amneziaVersion = version ?? options.amneziaVersion
        return options
    }

    private static func parseAllowedIPs(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return ["0.0.0.0/0", "::/0"] }
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Split host:port or [IPv6]:port into Core WireGuardPeer address + port fields.
    public static func splitPeerHostPort(_ endpoint: String, defaultPort: UInt16 = 51820) -> (String, UInt16) {
        if endpoint.hasPrefix("["), let close = endpoint.firstIndex(of: "]") {
            let host = String(endpoint[endpoint.index(after: endpoint.startIndex)..<close])
            let rest = endpoint[endpoint.index(after: close)...]
            let port = UInt16(rest.dropFirst()) ?? defaultPort
            return (host, port)
        }
        if let idx = endpoint.lastIndex(of: ":"),
           let port = UInt16(endpoint[endpoint.index(after: idx)...])
        {
            return (String(endpoint[..<idx]), port)
        }
        return (endpoint, defaultPort)
    }

    /// sing-box / lx endpoint JSON object (`type: wireguard` + AWG fields).
    public func endpointJSON(tag: String = "wg-out") throws -> [String: Any] {
        guard VPNDirectCoreCapabilities.current.supportsAWG || hasNoObfuscation else {
            throw VPNDirectCoreError.unsupportedFeature(component: "amneziawg", detail: "Current Libbox build lacks with_awg")
        }
        guard !peers.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing peers")
        }

        var endpoint: [String: Any] = [
            "type": "wireguard",
            "tag": tag,
            "private_key": privateKey,
            "address": address,
            "peers": peers.map { peer -> [String: Any] in
                var p: [String: Any] = [
                    "public_key": peer.publicKey,
                    "allowed_ips": peer.allowedIPs,
                ]
                if let preSharedKey = peer.preSharedKey { p["pre_shared_key"] = preSharedKey }
                if let ep = peer.endpoint, !ep.isEmpty {
                    let (host, port) = Self.splitPeerHostPort(ep)
                    p["address"] = host
                    p["port"] = Int(port)
                }
                if let keepalive = peer.persistentKeepaliveInterval {
                    p["persistent_keepalive_interval"] = keepalive
                }
                return p
            },
        ]
        if let mtu { endpoint["mtu"] = mtu }

        // Obfuscation / AWG fields (only emit when set) — match donor AmneziaWGOptions JSON keys.
        if let jc { endpoint["jc"] = jc }
        if let jmin { endpoint["jmin"] = jmin }
        if let jmax { endpoint["jmax"] = jmax }
        if let s1 { endpoint["s1"] = s1 }
        if let s2 { endpoint["s2"] = s2 }
        if let s3 { endpoint["s3"] = s3 }
        if let s4 { endpoint["s4"] = s4 }
        if let h1 { endpoint["h1"] = h1 }
        if let h2 { endpoint["h2"] = h2 }
        if let h3 { endpoint["h3"] = h3 }
        if let h4 { endpoint["h4"] = h4 }
        if let i1 { endpoint["i1"] = i1 }
        if let i2 { endpoint["i2"] = i2 }
        if let i3 { endpoint["i3"] = i3 }
        if let i4 { endpoint["i4"] = i4 }
        if let i5 { endpoint["i5"] = i5 }
        if let id { endpoint["id"] = id }
        if let ip { endpoint["ip"] = ip }
        if let ib { endpoint["ib"] = ib }
        if let headerProtectionKey { endpoint["header_protection_key"] = headerProtectionKey }
        if let contentPaddingAddition { endpoint["content_padding_addition"] = contentPaddingAddition }
        if let randomTrailers { endpoint["random_trailers"] = randomTrailers }
        if let disableCookies { endpoint["disable_cookies"] = disableCookies }
        if let rekeyAfterTime { endpoint["rekey_after_time"] = rekeyAfterTime }
        if let rekeyTimeout { endpoint["rekey_timeout"] = rekeyTimeout }
        if let rejectAfterTime { endpoint["reject_after_time"] = rejectAfterTime }
        if let keepaliveTimeout { endpoint["keepalive_timeout"] = keepaliveTimeout }
        if let maxHandshakeAttempts { endpoint["max_handshake_attempts"] = maxHandshakeAttempts }
        if let persistentKeepaliveInterval { endpoint["persistent_keepalive_interval"] = persistentKeepaliveInterval }

        // amneziaVersion stays on the Swift model / UI metadata — never emit unknown sing-box keys.
        return endpoint
    }

    /// Parse Amnezia / wg-quick style `.conf` text into options (multi-peer aware).
    public static func parseConf(_ text: String, amneziaVersion: String = "2") throws -> AmneziaWGEndpointOptions {
        var privateKey = ""
        var address: [String] = []
        var mtu: Int?
        var peers: [Peer] = []
        var currentPeer: MutablePeer?
        var jc: Int?; var jmin: Int?; var jmax: Int?
        var s1: Int?; var s2: Int?; var s3: Int?; var s4: Int?
        var h1: String?; var h2: String?; var h3: String?; var h4: String?
        var i1: String?; var i2: String?; var i3: String?; var i4: String?; var i5: String?
        var id: String?; var ip: String?; var ib: String?
        var headerProtectionKey: String?
        var contentPaddingAddition: String?
        var randomTrailers: Bool?
        var disableCookies: Bool?
        var rekeyAfterTime: String?
        var rekeyTimeout: String?
        var rejectAfterTime: String?
        var keepaliveTimeout: String?
        var maxHandshakeAttempts: String?
        var persistentKeepaliveInterval: String?

        func flushPeer() {
            guard let peer = currentPeer, !peer.publicKey.isEmpty else {
                currentPeer = nil
                return
            }
            peers.append(
                Peer(
                    publicKey: peer.publicKey,
                    preSharedKey: peer.preSharedKey,
                    allowedIPs: peer.allowedIPs.isEmpty ? ["0.0.0.0/0", "::/0"] : peer.allowedIPs,
                    endpoint: peer.endpoint,
                    persistentKeepaliveInterval: peer.persistentKeepaliveInterval
                )
            )
            currentPeer = nil
        }

        var section = ""
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let next = line.lowercased()
                if next == "[peer]" {
                    flushPeer()
                    currentPeer = MutablePeer()
                } else if section == "[peer]" {
                    flushPeer()
                }
                section = next
                continue
            }
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = parts[1]
            switch (section, key) {
            case ("[interface]", "privatekey"): privateKey = value
            case ("[interface]", "address"): address = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case ("[interface]", "mtu"): mtu = Int(value)
            case ("[interface]", "jc"): jc = Int(value)
            case ("[interface]", "jmin"): jmin = Int(value)
            case ("[interface]", "jmax"): jmax = Int(value)
            case ("[interface]", "s1"): s1 = Int(value)
            case ("[interface]", "s2"): s2 = Int(value)
            case ("[interface]", "s3"): s3 = Int(value)
            case ("[interface]", "s4"): s4 = Int(value)
            case ("[interface]", "h1"): h1 = value
            case ("[interface]", "h2"): h2 = value
            case ("[interface]", "h3"): h3 = value
            case ("[interface]", "h4"): h4 = value
            case ("[interface]", "i1"): i1 = value
            case ("[interface]", "i2"): i2 = value
            case ("[interface]", "i3"): i3 = value
            case ("[interface]", "i4"): i4 = value
            case ("[interface]", "i5"): i5 = value
            case ("[interface]", "id"): id = value
            case ("[interface]", "ip"): ip = value
            case ("[interface]", "ib"): ib = value
            case ("[interface]", "headerprotectionkey"): headerProtectionKey = value
            case ("[interface]", "contentpaddingaddition"): contentPaddingAddition = value
            case ("[interface]", "randomtrailers"): randomTrailers = (value == "true" || value == "1")
            case ("[interface]", "disablecookies"), ("[interface]", "disablecookie"):
                disableCookies = (value == "true" || value == "1")
            case ("[interface]", "rekeyaftertime"): rekeyAfterTime = value
            case ("[interface]", "rekeytimeout"): rekeyTimeout = value
            case ("[interface]", "rejectaftertime"): rejectAfterTime = value
            case ("[interface]", "keepalivetimeout"): keepaliveTimeout = value
            case ("[interface]", "maxhandshakeattempts"): maxHandshakeAttempts = value
            case ("[interface]", "persistentkeepaliveinterval"): persistentKeepaliveInterval = value
            case ("[peer]", "publickey"):
                currentPeer = currentPeer ?? MutablePeer()
                currentPeer?.publicKey = value
            case ("[peer]", "presharedkey"):
                currentPeer = currentPeer ?? MutablePeer()
                currentPeer?.preSharedKey = value
            case ("[peer]", "allowedips"):
                currentPeer = currentPeer ?? MutablePeer()
                currentPeer?.allowedIPs = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case ("[peer]", "endpoint"):
                currentPeer = currentPeer ?? MutablePeer()
                currentPeer?.endpoint = value
            case ("[peer]", "persistentkeepalive"):
                currentPeer = currentPeer ?? MutablePeer()
                currentPeer?.persistentKeepaliveInterval = Int(value)
            default: break
            }
        }
        flushPeer()

        guard !privateKey.isEmpty, !peers.isEmpty, !address.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(
                component: "amneziawg",
                detail: "Missing private key, peer public key, or address"
            )
        }

        var options = AmneziaWGEndpointOptions(
            privateKey: privateKey,
            address: address,
            peers: peers,
            mtu: mtu,
            amneziaVersion: amneziaVersion
        )
        options.jc = jc; options.jmin = jmin; options.jmax = jmax
        options.s1 = s1; options.s2 = s2; options.s3 = s3; options.s4 = s4
        options.h1 = h1; options.h2 = h2; options.h3 = h3; options.h4 = h4
        options.i1 = i1; options.i2 = i2; options.i3 = i3; options.i4 = i4; options.i5 = i5
        options.id = id; options.ip = ip; options.ib = ib
        options.headerProtectionKey = headerProtectionKey
        options.contentPaddingAddition = contentPaddingAddition
        options.randomTrailers = randomTrailers
        options.disableCookies = disableCookies
        options.rekeyAfterTime = rekeyAfterTime
        options.rekeyTimeout = rekeyTimeout
        options.rejectAfterTime = rejectAfterTime
        options.keepaliveTimeout = keepaliveTimeout
        options.maxHandshakeAttempts = maxHandshakeAttempts
        options.persistentKeepaliveInterval = persistentKeepaliveInterval
        return options
    }

    private struct MutablePeer {
        var publicKey = ""
        var preSharedKey: String?
        var allowedIPs: [String] = []
        var endpoint: String?
        var persistentKeepaliveInterval: Int?
    }
}

/// MASQUE CONNECT-IP / Cloudflare WARP outbound (sing-box-lx).
public struct MasqueOutboundOptions: Equatable, Sendable {
    public var server: String
    public var serverPort: Int
    public var profile: String // cloudflare | standard
    public var vhttp: String // h3 | h2
    public var privateKey: String
    public var publicKey: String
    public var ip: String?
    public var ipv6: String?
    public var tlsServerName: String?

    public init(
        server: String,
        serverPort: Int = 443,
        profile: String = "cloudflare",
        vhttp: String = "h3",
        privateKey: String,
        publicKey: String,
        ip: String? = nil,
        ipv6: String? = nil,
        tlsServerName: String? = nil
    ) {
        self.server = server
        self.serverPort = serverPort
        self.profile = profile
        self.vhttp = vhttp
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.ip = ip
        self.ipv6 = ipv6
        self.tlsServerName = tlsServerName
    }

    public func outboundJSON(tag: String = "masque-out") throws -> [String: Any] {
        guard VPNDirectCoreCapabilities.current.supportsMASQUEConnectIP else {
            throw VPNDirectCoreError.unsupportedFeature(component: "masque", detail: "CONNECT-IP not available in this Libbox build")
        }
        var outbound: [String: Any] = [
            "type": "masque",
            "tag": tag,
            "server": server,
            "server_port": serverPort,
            "profile": profile,
            "vhttp": vhttp,
            "private_key": privateKey,
            "public_key": publicKey,
        ]
        if let ip { outbound["ip"] = ip }
        if let ipv6 { outbound["ipv6"] = ipv6 }
        if let tlsServerName {
            outbound["tls"] = ["server_name": tlsServerName]
        }
        return outbound
    }
}

/// Structured import failure metadata for UI / diagnostics (does not replace enum cases).
public struct VPNDirectImportFailure: Equatable, Sendable {
    public var ecosystem: String?
    public var format: String?
    public var protocolID: String?
    public var field: String?
    public var retryable: Bool
    public var detail: String

    public init(
        ecosystem: String? = nil,
        format: String? = nil,
        protocolID: String? = nil,
        field: String? = nil,
        retryable: Bool,
        detail: String
    ) {
        self.ecosystem = ecosystem
        self.format = format
        self.protocolID = protocolID
        self.field = field
        self.retryable = retryable
        self.detail = detail
    }
}

/// Normalized Core-facing errors for UI (v2).
public enum VPNDirectCoreError: LocalizedError {
    case unsupportedFeature(component: String, detail: String)
    case malformedConfig(component: String, detail: String)
    case coreError(detail: String)
    case coreRejected(ecosystem: String?, protocolID: String?, detail: String)
    case unsupportedTransport(transport: String, detail: String)
    case unsupportedSecurity(security: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFeature(component, _):
            return String(localized: "This server uses \(component), which is not available in this build.")
        case let .malformedConfig(component, _):
            return String(localized: "Invalid \(component) configuration.")
        case .coreError, .coreRejected:
            return String(localized: "The VPN core rejected this configuration.")
        case let .unsupportedTransport(transport, _):
            return String(localized: "This server uses transport \(transport), which is not supported yet.")
        case let .unsupportedSecurity(security, _):
            return String(localized: "This server uses security \(security), which is not supported yet.")
        }
    }

    public var debugDescription: String {
        let failure = asImportFailure()
        let head: String
        switch self {
        case let .unsupportedFeature(component, _):
            head = "unsupportedFeature(\(component))"
        case let .malformedConfig(component, _):
            head = "malformedConfig(\(component))"
        case .coreError:
            head = "coreError"
        case let .coreRejected(ecosystem, protocolID, _):
            head = "coreRejected ecosystem=\(ecosystem ?? "-") protocol=\(protocolID ?? "-")"
        case let .unsupportedTransport(transport, _):
            head = "unsupportedTransport(\(transport))"
        case let .unsupportedSecurity(security, _):
            head = "unsupportedSecurity(\(security))"
        }
        if let field = failure.field, !field.isEmpty {
            return VPNDirectRedactor.redact("\(head) field=\(field): \(failure.detail)")
        }
        return VPNDirectRedactor.redact("\(head): \(failure.detail)")
    }

    /// Map this error into structured import failure metadata without changing throw sites.
    public func asImportFailure(
        ecosystem: String? = nil,
        format: String? = nil,
        protocolID: String? = nil,
        field: String? = nil
    ) -> VPNDirectImportFailure {
        switch self {
        case let .unsupportedFeature(component, detail):
            return VPNDirectImportFailure(
                ecosystem: ecosystem,
                format: format ?? component,
                protocolID: protocolID ?? component,
                field: field,
                retryable: false,
                detail: detail
            )
        case let .malformedConfig(component, detail):
            return VPNDirectImportFailure(
                ecosystem: ecosystem,
                format: format ?? component,
                protocolID: protocolID,
                field: field,
                retryable: false,
                detail: detail
            )
        case let .coreError(detail):
            return VPNDirectImportFailure(
                ecosystem: ecosystem,
                format: format,
                protocolID: protocolID,
                field: field,
                retryable: true,
                detail: detail
            )
        case let .coreRejected(eco, proto, detail):
            return VPNDirectImportFailure(
                ecosystem: ecosystem ?? eco,
                format: format,
                protocolID: protocolID ?? proto,
                field: field,
                retryable: false,
                detail: detail
            )
        case let .unsupportedTransport(transport, detail):
            return VPNDirectImportFailure(
                ecosystem: ecosystem,
                format: format,
                protocolID: protocolID,
                field: field ?? "transport",
                retryable: false,
                detail: "\(transport): \(detail)"
            )
        case let .unsupportedSecurity(security, detail):
            return VPNDirectImportFailure(
                ecosystem: ecosystem,
                format: format,
                protocolID: protocolID,
                field: field ?? "security",
                retryable: false,
                detail: "\(security): \(detail)"
            )
        }
    }

    public var importFailure: VPNDirectImportFailure {
        asImportFailure()
    }
}
