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
    public static let tuic = VPNDirectProtocolID(rawValue: "tuic")
    public static let anytls = VPNDirectProtocolID(rawValue: "anytls")
    public static let wireguard = VPNDirectProtocolID(rawValue: "wireguard")
    public static let amneziawg = VPNDirectProtocolID(rawValue: "amneziawg")
    public static let masque = VPNDirectProtocolID(rawValue: "masque")
    public static let mieru = VPNDirectProtocolID(rawValue: "mieru")
    public static let socks = VPNDirectProtocolID(rawValue: "socks")
    public static let http = VPNDirectProtocolID(rawValue: "http")
    public static let ssh = VPNDirectProtocolID(rawValue: "ssh")
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
public struct NormalizedNode: Equatable, Sendable {
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
    /// Original share link / fragment when available.
    public var source: String?
    /// Pre-built sing-box outbound when the adapter already constructed one.
    public var outbound: [String: Any]?

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
        source: String? = nil,
        outbound: [String: Any]? = nil
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
        self.source = source
        self.outbound = outbound
    }

    public static func == (lhs: NormalizedNode, rhs: NormalizedNode) -> Bool {
        lhs.name == rhs.name
            && lhs.protocolID == rhs.protocolID
            && lhs.server == rhs.server
            && lhs.port == rhs.port
            && lhs.transport == rhs.transport
            && lhs.security == rhs.security
            && lhs.obfuscation == rhs.obfuscation
            && lhs.uuid == rhs.uuid
            && lhs.attributes == rhs.attributes
            && lhs.source == rhs.source
    }
}
