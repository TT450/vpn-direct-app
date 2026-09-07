import Foundation

/// Extensible protocol identity for VPN Direct normalized nodes.
public struct VPNDirectProtocolID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }

    public static let vless = VPNDirectProtocolID(rawValue: "vless")
    public static let vmess = VPNDirectProtocolID(rawValue: "vmess")
    public static let trojan = VPNDirectProtocolID(rawValue: "trojan")
    public static let shadowsocks = VPNDirectProtocolID(rawValue: "shadowsocks")
    public static let hysteria2 = VPNDirectProtocolID(rawValue: "hysteria2")
    public static let hysteria = VPNDirectProtocolID(rawValue: "hysteria")
    public static let tuic = VPNDirectProtocolID(rawValue: "tuic")
    public static let anytls = VPNDirectProtocolID(rawValue: "anytls")
    public static let wireguard = VPNDirectProtocolID(rawValue: "wireguard")
    public static let amneziawg = VPNDirectProtocolID(rawValue: "amneziawg")
    public static let masque = VPNDirectProtocolID(rawValue: "masque")
    public static let mieru = VPNDirectProtocolID(rawValue: "mieru")
    public static let socks = VPNDirectProtocolID(rawValue: "socks")
    public static let http = VPNDirectProtocolID(rawValue: "http")
    public static let ssh = VPNDirectProtocolID(rawValue: "ssh")
    public static let naive = VPNDirectProtocolID(rawValue: "naive")
    public static let shadowtls = VPNDirectProtocolID(rawValue: "shadowtls")
}

/// Extensible transport identity (tcp/ws/xhttp/…).
public struct VPNDirectTransportID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }

    public static let tcp = VPNDirectTransportID(rawValue: "tcp")
    public static let ws = VPNDirectTransportID(rawValue: "ws")
    public static let grpc = VPNDirectTransportID(rawValue: "grpc")
    public static let httpupgrade = VPNDirectTransportID(rawValue: "httpupgrade")
    public static let http = VPNDirectTransportID(rawValue: "http")
    public static let xhttp = VPNDirectTransportID(rawValue: "xhttp")
    public static let quic = VPNDirectTransportID(rawValue: "quic")
}

/// Extensible security identity (none/tls/reality/…).
public struct VPNDirectSecurityID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }

    public static let none = VPNDirectSecurityID(rawValue: "none")
    public static let tls = VPNDirectSecurityID(rawValue: "tls")
    public static let reality = VPNDirectSecurityID(rawValue: "reality")
}

/// Extensible obfuscation identity (salamander/gecko/…).
public struct VPNDirectObfuscationID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }
}

/// Canonical intermediate node produced by VPN Direct parsers.
public struct NormalizedNode: Equatable {
    public var name: String
    public var protocolID: VPNDirectProtocolID
    public var server: String
    public var port: Int
    public var transport: VPNDirectTransportID?
    public var security: VPNDirectSecurityID?
    public var obfuscation: VPNDirectObfuscationID?
    public var uuid: String?
    /// Protocol-specific fields preserved for builders (share-link query, JSON keys, …).
    public var attributes: [String: String]
    /// Opaque extras: panel metadata, future fields, unclassified keys (never silently dropped).
    /// Legacy string map — prefer `typedExtensions` for arrays/objects.
    public var rawExtensions: [String: String]
    /// Typed extensions (lossless arrays/objects). Keys here are also mirrored into rawExtensions as flattened strings for policy scans.
    public var typedExtensions: [String: VPNDirectJSONValue]
    /// Original share link / fragment when available.
    public var source: String?
    /// Pre-built sing-box outbound when the adapter already constructed one.
    public var outbound: [String: Any]?
    /// Structured WireGuard / AmneziaWG endpoint (multi-peer + AWG fields). Preferred over flat attrs.
    public var wireguardEndpoint: AmneziaWGEndpointOptions?
    /// Optional detour / next-hop tag (Xray dialerProxy → sing-box detour).
    public var detour: String?

    public init(
        name: String,
        protocolID: VPNDirectProtocolID,
        server: String,
        port: Int,
        transport: VPNDirectTransportID? = nil,
        security: VPNDirectSecurityID? = nil,
        obfuscation: VPNDirectObfuscationID? = nil,
        uuid: String? = nil,
        attributes: [String: String] = [:],
        rawExtensions: [String: String] = [:],
        typedExtensions: [String: VPNDirectJSONValue] = [:],
        source: String? = nil,
        outbound: [String: Any]? = nil,
        wireguardEndpoint: AmneziaWGEndpointOptions? = nil,
        detour: String? = nil
    ) {
        self.name = name
        self.protocolID = protocolID
        self.server = server
        self.port = port
        self.transport = transport
        self.security = security
        self.obfuscation = obfuscation
        self.uuid = uuid
        self.attributes = attributes
        var raw = rawExtensions
        var typed = typedExtensions
        for (k, v) in typed {
            if raw[k] == nil {
                raw[k] = v.flattenedString
            }
        }
        for (k, v) in raw where typed[k] == nil {
            typed[k] = .string(v)
        }
        self.rawExtensions = raw
        self.typedExtensions = typed
        self.source = source
        self.outbound = outbound
        self.wireguardEndpoint = wireguardEndpoint
        self.detour = detour
    }

    /// Connection-critical equality (REQ-P136 / REQ-P137).
    /// Excludes `source` (provenance) and legacy `outbound` prebuilt JSON
    /// (builders must consume typed model; outbound is not part of semantic identity).
    public func connectionEquals(_ other: NormalizedNode) -> Bool {
        name == other.name
            && protocolID == other.protocolID
            && server == other.server
            && port == other.port
            && transport == other.transport
            && security == other.security
            && obfuscation == other.obfuscation
            && uuid == other.uuid
            && attributes == other.attributes
            && rawExtensions == other.rawExtensions
            && typedExtensions == other.typedExtensions
            && detour == other.detour
            && wireguardEndpoint == other.wireguardEndpoint
    }

    public static func == (lhs: NormalizedNode, rhs: NormalizedNode) -> Bool {
        // Semantic connection equality; provenance (`source`) intentionally excluded.
        lhs.connectionEquals(rhs)
    }
}
