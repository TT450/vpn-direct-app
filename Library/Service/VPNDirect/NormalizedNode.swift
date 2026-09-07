import Foundation

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

public struct VPNDirectSecurityID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }
    public static let none = VPNDirectSecurityID(rawValue: "none")
    public static let tls = VPNDirectSecurityID(rawValue: "tls")
    public static let reality = VPNDirectSecurityID(rawValue: "reality")
}

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
    public var attributes: [String: String]
    public var rawExtensions: [String: String]
    public var typedExtensions: [String: VPNDirectJSONValue]
    /// Provenance only; never part of connection semantics.
    public var source: String?
    /// Transitional legacy runtime JSON. Remove after all production writers migrate to typed fields.
    public var outbound: [String: Any]?
    public var wireguardEndpoint: AmneziaWGEndpointOptions?
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
        for (key, value) in typed where raw[key] == nil { raw[key] = value.flattenedString }
        for (key, value) in raw where typed[key] == nil { typed[key] = .string(value) }
        self.rawExtensions = raw
        self.typedExtensions = typed
        self.source = source
        self.outbound = outbound
        self.wireguardEndpoint = wireguardEndpoint
        self.detour = detour
    }

    /// Connection-critical equality (REQ-P136 / REQ-P137).
    /// `source` is excluded because it is provenance. While the legacy `outbound` escape hatch exists,
    /// its canonical JSON must participate in semantic equality so runtime changes cannot be missed.
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
            && Self.canonicalLegacyOutbound(outbound) == Self.canonicalLegacyOutbound(other.outbound)
    }

    public static func == (lhs: NormalizedNode, rhs: NormalizedNode) -> Bool {
        lhs.connectionEquals(rhs)
    }

    private static func canonicalLegacyOutbound(_ value: [String: Any]?) -> Data? {
        guard let value, !value.isEmpty else { return nil }
        guard JSONSerialization.isValidJSONObject(value) else {
            // A non-JSON legacy outbound must never compare equal to an unrelated runtime object.
            return String(describing: value).data(using: .utf8)
        }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
