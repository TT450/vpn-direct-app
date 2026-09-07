import Foundation

/// Canonical WireGuard / AmneziaWG endpoint model for the pinned
/// `Leadaxe/sing-box-lx v1.14.0-lx.35` endpoint schema.
///
/// Keep this independent from the deprecated sing-box WireGuard outbound.
public struct NormalizedWireGuardEndpoint: Equatable, Sendable {
    public struct RangeValue: Equatable, Sendable {
        public let canonical: String

        public init(_ raw: String) throws {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw VPNDirectCoreError.malformedConfig(component: "amneziawg", detail: "Empty AWG range")
            }
            let parts = trimmed.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 1 || parts.count == 2,
                  let start = UInt32(parts[0].trimmingCharacters(in: .whitespaces))
            else {
                throw VPNDirectCoreError.malformedConfig(component: "amneziawg", detail: "Invalid AWG range: \(raw)")
            }
            let end: UInt32
            if parts.count == 2 {
                guard let parsed = UInt32(parts[1].trimmingCharacters(in: .whitespaces)), parsed >= start else {
                    throw VPNDirectCoreError.malformedConfig(component: "amneziawg", detail: "Invalid AWG range: \(raw)")
                }
                end = parsed
            } else {
                end = start
            }
            guard end != 0 else {
                throw VPNDirectCoreError.malformedConfig(component: "amneziawg", detail: "Zero AWG range is unset and must not be emitted")
            }
            canonical = start == end ? String(start) : "\(start)-\(end)"
        }

        /// Pinned Core marshals a single AWGRange as JSON number and a real range as string.
        public var jsonValue: Any {
            if !canonical.contains("-"), let value = UInt32(canonical) {
                return Int(value)
            }
            return canonical
        }
    }

    public struct Peer: Equatable, Sendable {
        public var host: String?
        public var port: Int?
        public var publicKey: String
        public var preSharedKey: String?
        public var allowedIPs: [String]
        public var persistentKeepaliveInterval: RangeValue?
        public var reserved: [UInt8]

        public init(
            host: String? = nil,
            port: Int? = nil,
            publicKey: String,
            preSharedKey: String? = nil,
            allowedIPs: [String] = [],
            persistentKeepaliveInterval: RangeValue? = nil,
            reserved: [UInt8] = []
        ) {
            self.host = host
            self.port = port
            self.publicKey = publicKey
            self.preSharedKey = preSharedKey
            self.allowedIPs = allowedIPs
            self.persistentKeepaliveInterval = persistentKeepaliveInterval
            self.reserved = reserved
        }
    }

    public var system: Bool?
    public var interfaceName: String?
    public var mtu: Int?
    public var address: [String]
    public var privateKey: String
    public var listenPort: Int?
    public var peers: [Peer]
    public var udpTimeout: String?
    public var udpMapping: String?
    public var udpFiltering: String?
    public var udpNATMax: Int?
    public var workers: Int?

    // AWG 2.0 / classic fields.
    public var jc: Int?
    public var jmin: Int?
    public var jmax: Int?
    public var s1: Int?
    public var s2: Int?
    public var s3: Int?
    public var s4: Int?
    public var h1: RangeValue?
    public var h2: RangeValue?
    public var h3: RangeValue?
    public var h4: RangeValue?
    public var i1: String?
    public var i2: String?
    public var i3: String?
    public var i4: String?
    public var i5: String?
    public var masqueradeDomain: String?
    public var masqueradeProtocol: String?
    public var masqueradeBrowser: String?

    // AWG 3.x fields in pinned donor.
    public var headerProtectionKey: String?
    public var contentPaddingAddition: RangeValue?
    public var rekeyAfterTime: RangeValue?
    public var rekeyTimeout: RangeValue?
    public var rejectAfterTime: RangeValue?
    public var keepaliveTimeout: RangeValue?
    public var maxHandshakeAttempts: RangeValue?
    public var randomTrailers: Bool?
    public var disableCookies: Bool?

    /// Provenance only. Never emitted into sing-box JSON.
    public var declaredAmneziaVersion: String?

    public init(privateKey: String, address: [String], peers: [Peer]) {
        self.privateKey = privateKey
        self.address = address
        self.peers = peers
    }

    public var isAmnezia: Bool {
        jc != nil || jmin != nil || jmax != nil || s1 != nil || s2 != nil || s3 != nil || s4 != nil
            || h1 != nil || h2 != nil || h3 != nil || h4 != nil
            || i1 != nil || i2 != nil || i3 != nil || i4 != nil || i5 != nil
            || masqueradeDomain != nil || masqueradeProtocol != nil || masqueradeBrowser != nil
            || headerProtectionKey != nil || contentPaddingAddition != nil || rekeyAfterTime != nil
            || rekeyTimeout != nil || rejectAfterTime != nil || keepaliveTimeout != nil
            || maxHandshakeAttempts != nil || randomTrailers != nil || disableCookies != nil
            || peers.contains(where: { $0.persistentKeepaliveInterval?.canonical.contains("-") == true })
    }

    public func endpointJSON(tag: String) throws -> [String: Any] {
        guard !privateKey.isEmpty, !address.isEmpty, !peers.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing private key, interface address, or peer")
        }
        if isAmnezia && !VPNDirectCoreCapabilities.current.supportsAWG {
            throw VPNDirectCoreError.unsupportedFeature(component: "amneziawg", detail: "Current Libbox build lacks with_awg")
        }

        var object: [String: Any] = [
            "type": "wireguard",
            "tag": tag,
            "address": address,
            "private_key": privateKey,
        ]
        if let system { object["system"] = system }
        if let interfaceName, !interfaceName.isEmpty { object["name"] = interfaceName }
        if let mtu { object["mtu"] = mtu }
        if let listenPort { object["listen_port"] = listenPort }
        if let udpTimeout { object["udp_timeout"] = udpTimeout }
        if let udpMapping { object["udp_mapping"] = udpMapping }
        if let udpFiltering { object["udp_filtering"] = udpFiltering }
        if let udpNATMax { object["udp_nat_max"] = udpNATMax }
        if let workers { object["workers"] = workers }

        object["peers"] = try peers.map { peer -> [String: Any] in
            guard !peer.publicKey.isEmpty else {
                throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Peer missing public key")
            }
            if (peer.host == nil) != (peer.port == nil) {
                throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Peer endpoint requires both address and port")
            }
            var value: [String: Any] = ["public_key": peer.publicKey]
            if let host = peer.host { value["address"] = host }
            if let port = peer.port { value["port"] = port }
            if let key = peer.preSharedKey, !key.isEmpty { value["pre_shared_key"] = key }
            if !peer.allowedIPs.isEmpty { value["allowed_ips"] = peer.allowedIPs }
            if let keepalive = peer.persistentKeepaliveInterval { value["persistent_keepalive_interval"] = keepalive.jsonValue }
            if !peer.reserved.isEmpty { value["reserved"] = peer.reserved.map(Int.init) }
            return value
        }

        if let jc { object["jc"] = jc }
        if let jmin { object["jmin"] = jmin }
        if let jmax { object["jmax"] = jmax }
        if let s1 { object["s1"] = s1 }
        if let s2 { object["s2"] = s2 }
        if let s3 { object["s3"] = s3 }
        if let s4 { object["s4"] = s4 }
        if let h1 { object["h1"] = h1.jsonValue }
        if let h2 { object["h2"] = h2.jsonValue }
        if let h3 { object["h3"] = h3.jsonValue }
        if let h4 { object["h4"] = h4.jsonValue }
        if let i1 { object["i1"] = i1 }
        if let i2 { object["i2"] = i2 }
        if let i3 { object["i3"] = i3 }
        if let i4 { object["i4"] = i4 }
        if let i5 { object["i5"] = i5 }
        if let masqueradeDomain { object["id"] = masqueradeDomain }
        if let masqueradeProtocol { object["ip"] = masqueradeProtocol }
        if let masqueradeBrowser { object["ib"] = masqueradeBrowser }
        if let headerProtectionKey { object["header_protection_key"] = headerProtectionKey }
        if let contentPaddingAddition { object["content_padding_addition"] = contentPaddingAddition.jsonValue }
        if let rekeyAfterTime { object["rekey_after_time"] = rekeyAfterTime.jsonValue }
        if let rekeyTimeout { object["rekey_timeout"] = rekeyTimeout.jsonValue }
        if let rejectAfterTime { object["reject_after_time"] = rejectAfterTime.jsonValue }
        if let keepaliveTimeout { object["keepalive_timeout"] = keepaliveTimeout.jsonValue }
        if let maxHandshakeAttempts { object["max_handshake_attempts"] = maxHandshakeAttempts.jsonValue }
        if let randomTrailers { object["random_trailers"] = randomTrailers }
        if let disableCookies { object["disable_cookies"] = disableCookies }
        return object
    }

    public static func parseConf(_ text: String, declaredVersion: String? = nil) throws -> NormalizedWireGuardEndpoint {
        var privateKey = ""
        var addresses: [String] = []
        var listenPort: Int?
        var mtu: Int?
        var peers: [Peer] = []
        var peer = MutablePeer()
        var inPeer = false

        var result = NormalizedWireGuardEndpoint(privateKey: "", address: [], peers: [])
        result.declaredAmneziaVersion = declaredVersion

        func boolValue(_ raw: String, key: String) throws -> Bool {
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true": return true
            case "0", "false": return false
            default: throw VPNDirectCoreError.malformedConfig(component: "amneziawg", detail: "Invalid boolean for \(key): \(raw)")
            }
        }

        func endpointParts(_ raw: String) throws -> (String, Int) {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("[") {
                guard let end = value.lastIndex(of: "]"), end < value.index(before: value.endIndex), value[value.index(after: end)] == ":",
                      let port = Int(value[value.index(end, offsetBy: 2)...]), (1...65535).contains(port)
                else { throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Invalid peer endpoint: \(raw)") }
                return (String(value[value.index(after: value.startIndex)..<end]), port)
            }
            guard let colon = value.lastIndex(of: ":"), let port = Int(value[value.index(after: colon)...]), (1...65535).contains(port) else {
                throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Invalid peer endpoint: \(raw)")
            }
            return (String(value[..<colon]), port)
        }

        func flushPeer() throws {
            guard inPeer else { return }
            guard !peer.publicKey.isEmpty else {
                throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Peer missing PublicKey")
            }
            peers.append(Peer(
                host: peer.host,
                port: peer.port,
                publicKey: peer.publicKey,
                preSharedKey: peer.preSharedKey,
                allowedIPs: peer.allowedIPs,
                persistentKeepaliveInterval: peer.keepalive,
                reserved: peer.reserved
            ))
            peer = MutablePeer()
            inPeer = false
        }

        var section = ""
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                try flushPeer()
                section = line.lowercased()
                inPeer = section == "[peer]"
                continue
            }
            let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            if section == "[interface]" {
                switch key {
                case "privatekey": privateKey = value
                case "address": addresses = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                case "listenport": listenPort = Int(value)
                case "mtu": mtu = Int(value)
                case "jc": result.jc = Int(value)
                case "jmin": result.jmin = Int(value)
                case "jmax": result.jmax = Int(value)
                case "s1": result.s1 = Int(value)
                case "s2": result.s2 = Int(value)
                case "s3": result.s3 = Int(value)
                case "s4": result.s4 = Int(value)
                case "h1": result.h1 = try RangeValue(value)
                case "h2": result.h2 = try RangeValue(value)
                case "h3": result.h3 = try RangeValue(value)
                case "h4": result.h4 = try RangeValue(value)
                case "i1": result.i1 = value
                case "i2": result.i2 = value
                case "i3": result.i3 = value
                case "i4": result.i4 = value
                case "i5": result.i5 = value
                case "id": result.masqueradeDomain = value
                case "ip": result.masqueradeProtocol = value
                case "ib": result.masqueradeBrowser = value
                case "headerprotectionkey": result.headerProtectionKey = value
                case "contentpaddingaddition": result.contentPaddingAddition = try RangeValue(value)
                case "rekeyaftertime": result.rekeyAfterTime = try RangeValue(value)
                case "rekeytimeout": result.rekeyTimeout = try RangeValue(value)
                case "rejectaftertime": result.rejectAfterTime = try RangeValue(value)
                case "keepalivetimeout": result.keepaliveTimeout = try RangeValue(value)
                case "maxhandshakeattempts": result.maxHandshakeAttempts = try RangeValue(value)
                case "randomtrailers": result.randomTrailers = try boolValue(value, key: key)
                case "disablecookies", "disablecookie": result.disableCookies = try boolValue(value, key: key)
                default: break
                }
            } else if section == "[peer]" {
                switch key {
                case "publickey": peer.publicKey = value
                case "presharedkey": peer.preSharedKey = value
                case "allowedips": peer.allowedIPs = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                case "endpoint":
                    let parsed = try endpointParts(value)
                    peer.host = parsed.0
                    peer.port = parsed.1
                case "persistentkeepalive", "persistentkeepaliveinterval": peer.keepalive = try RangeValue(value)
                case "reserved":
                    let values = value.split(separator: ",").compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
                    guard values.count == value.split(separator: ",").count else {
                        throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Invalid Reserved bytes")
                    }
                    peer.reserved = values
                default: break
                }
            }
        }
        try flushPeer()

        guard !privateKey.isEmpty, !addresses.isEmpty, !peers.isEmpty else {
            throw VPNDirectCoreError.malformedConfig(component: "wireguard", detail: "Missing PrivateKey, Address, or Peer")
        }
        result.privateKey = privateKey
        result.address = addresses
        result.peers = peers
        result.listenPort = listenPort
        result.mtu = mtu
        return result
    }

    private struct MutablePeer {
        var host: String?
        var port: Int?
        var publicKey = ""
        var preSharedKey: String?
        var allowedIPs: [String] = []
        var keepalive: RangeValue?
        var reserved: [UInt8] = []
    }
}
