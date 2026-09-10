import Foundation

#if canImport(Libbox)
    import Libbox
#endif

/// Runtime feature discovery for VPN Direct Core / Libbox.
/// Builders and UI must query this instead of hardcoding stock-Libbox limits.
///
/// Fail-closed: unproven capabilities are false / empty.
///
/// Sources (priority):
/// 1. Env `VPN_DIRECT_CAPABILITY_JSON` — tests/CI
/// 2. Linked Libbox CapabilityJSON when ABI magic + API version match (source of truth)
/// 3. Linked per-feature exports (fallback when JSON missing but ABI ok)
/// 4. Sidecar / build-tag strings are **informational only** (`buildTags`); they never
///    enable custom VPN Direct features when ABI is incompatible
/// 5. Stock / incompatible ABI ⇒ all custom features false
public struct VPNDirectCoreCapabilities: Equatable {
    public static let expectedMagic = "VPN_DIRECT_CORE"
    public static let expectedAPIVersion = 1

    public var coreName: String
    public var coreVersion: String
    public var singBoxVersion: String
    public var buildTags: [String]
    public var abiCompatible: Bool

    public var supportsXHTTP: Bool
    public var supportsAWG: Bool
    public var amneziaWGVersions: [String]
    public var supportsMASQUEConnectIP: Bool
    public var supportsMASQUEConnectUDP: Bool
    public var supportsVLESSEncryption: Bool
    public var supportsMieru: Bool
    public var hysteria2Obfuscations: [String]
    public var vlessTransports: [String]
    public var vlessSecurity: [String]
    public var supportsHysteria2: Bool

    /// Raw Core CapabilityJSON object when ABI is compatible (mirrored, not rewritten).
    public var coreDocument: [String: Any]

    public static var current: VPNDirectCoreCapabilities {
        probe()
    }

    public static func == (lhs: VPNDirectCoreCapabilities, rhs: VPNDirectCoreCapabilities) -> Bool {
        lhs.coreName == rhs.coreName
            && lhs.coreVersion == rhs.coreVersion
            && lhs.singBoxVersion == rhs.singBoxVersion
            && lhs.buildTags == rhs.buildTags
            && lhs.abiCompatible == rhs.abiCompatible
            && lhs.supportsXHTTP == rhs.supportsXHTTP
            && lhs.supportsAWG == rhs.supportsAWG
            && lhs.amneziaWGVersions == rhs.amneziaWGVersions
            && lhs.supportsMASQUEConnectIP == rhs.supportsMASQUEConnectIP
            && lhs.supportsMASQUEConnectUDP == rhs.supportsMASQUEConnectUDP
            && lhs.supportsVLESSEncryption == rhs.supportsVLESSEncryption
            && lhs.supportsMieru == rhs.supportsMieru
            && lhs.hysteria2Obfuscations == rhs.hysteria2Obfuscations
            && lhs.vlessTransports == rhs.vlessTransports
            && lhs.vlessSecurity == rhs.vlessSecurity
            && lhs.supportsHysteria2 == rhs.supportsHysteria2
    }

    public static func probe() -> VPNDirectCoreCapabilities {
        let singBoxVersion = libboxVersionString()

        if let envJSON = ProcessInfo.processInfo.environment["VPN_DIRECT_CAPABILITY_JSON"],
           !envJSON.isEmpty,
           let fromEnv = decodeCapabilityJSON(envJSON, singBoxVersion: singBoxVersion)
        {
            return fromEnv
        }

        let stamped = readVersionStamp()
        let linked = readLinkedExports()

        var tags = stamped.tags
        if tags.isEmpty {
            tags = linked.tags
        }
        if let envTags = ProcessInfo.processInfo.environment["VPN_DIRECT_BUILD_TAGS"], !envTags.isEmpty {
            tags = envTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }

        let abiOK = linked.present
            && linked.magic == expectedMagic
            && linked.apiVersion == expectedAPIVersion

        if abiOK,
           let json = linked.capabilityJSON,
           var decoded = decodeCapabilityJSON(json, singBoxVersion: singBoxVersion)
        {
            if decoded.buildTags.isEmpty {
                decoded.buildTags = tags
            }
            return decoded
        }

        if abiOK {
            // Prefer explicit linked exports; tags from the linked binary may fill gaps only while ABI is OK.
            let hasXHTTP = linked.xhttp ?? false
            let hasAWG = linked.awg ?? false
            let versions = linked.awgVersions
            let hysteriaObfs = linked.hysteria2Obfuscations
            let transports = linked.vlessTransports.isEmpty
                ? fallbackVLESSTransports(xhttp: hasXHTTP)
                : linked.vlessTransports
            let security = linked.vlessSecurity.isEmpty ? ["none", "tls", "reality"] : linked.vlessSecurity

            return VPNDirectCoreCapabilities(
                coreName: linked.coreName ?? stamped.coreName ?? "VPNDirectCore",
                coreVersion: linked.coreVersion
                    ?? stamped.coreVersion
                    ?? ProcessInfo.processInfo.environment["VPN_DIRECT_CORE_VERSION"]
                    ?? "0.1.0",
                singBoxVersion: singBoxVersion,
                buildTags: tags,
                abiCompatible: true,
                supportsXHTTP: hasXHTTP,
                supportsAWG: hasAWG,
                amneziaWGVersions: hasAWG ? versions : [],
                supportsMASQUEConnectIP: linked.masqueConnectIP ?? false,
                supportsMASQUEConnectUDP: linked.masqueConnectUDP ?? false,
                supportsVLESSEncryption: linked.vlessEncryption ?? false,
                supportsMieru: linked.mieru ?? false,
                hysteria2Obfuscations: hysteriaObfs,
                vlessTransports: transports,
                vlessSecurity: security,
                supportsHysteria2: linked.supportsHysteria2 ?? !hysteriaObfs.isEmpty,
                coreDocument: [:]
            )
        }

        // Stock / incompatible ABI: sidecar tags are debug info only — never gate features.
        return VPNDirectCoreCapabilities(
            coreName: stamped.coreName ?? "Libbox",
            coreVersion: stamped.coreVersion
                ?? ProcessInfo.processInfo.environment["VPN_DIRECT_CORE_VERSION"]
                ?? "stock",
            singBoxVersion: singBoxVersion,
            buildTags: tags,
            abiCompatible: false,
            supportsXHTTP: false,
            supportsAWG: false,
            amneziaWGVersions: [],
            supportsMASQUEConnectIP: false,
            supportsMASQUEConnectUDP: false,
            supportsVLESSEncryption: false,
            supportsMieru: false,
            hysteria2Obfuscations: [],
            vlessTransports: [],
            vlessSecurity: [],
            supportsHysteria2: false,
            coreDocument: [:]
        )
    }

    /// Mirrors Core CapabilityJSON when available. Does not invent protocol lists.
    public func jsonObject() -> [String: Any] {
        if !coreDocument.isEmpty {
            var mirrored = coreDocument
            mirrored["abiCompatible"] = abiCompatible
            return mirrored
        }

        return [
            "abiCompatible": abiCompatible,
            "api": Self.expectedAPIVersion,
            "magic": Self.expectedMagic,
            "core": coreName,
            "version": coreVersion,
            "singBox": singBoxVersion,
            "tags": buildTags.joined(separator: ","),
            "xhttp": supportsXHTTP,
            "awg": supportsAWG,
            "awgVersions": amneziaWGVersions,
            "masqueConnectIP": supportsMASQUEConnectIP,
            "masqueConnectUDP": supportsMASQUEConnectUDP,
            "vlessEncryption": supportsVLESSEncryption,
            "mieru": supportsMieru,
            "hysteria2Obfuscations": hysteria2Obfuscations,
            "transports": [
                "tcp": vlessTransports.contains("tcp"),
                "ws": vlessTransports.contains("ws"),
                "grpc": vlessTransports.contains("grpc"),
                "httpupgrade": vlessTransports.contains("httpupgrade"),
                "http": vlessTransports.contains("http"),
                "xhttp": supportsXHTTP,
            ],
            "protocols": [
                "vless": [
                    "supported": !vlessTransports.isEmpty,
                    "transports": vlessTransports,
                    "security": vlessSecurity,
                    "encryption": supportsVLESSEncryption,
                ],
                "amneziawg": [
                    "supported": supportsAWG,
                    "versions": amneziaWGVersions,
                ],
                "masque": [
                    "connect_ip": supportsMASQUEConnectIP,
                    "connect_udp": supportsMASQUEConnectUDP,
                ],
                "mieru": [
                    "supported": supportsMieru,
                ],
                "hysteria2": [
                    "supported": supportsHysteria2,
                    "obfuscation": hysteria2Obfuscations,
                ],
            ],
        ]
    }

    private static func fallbackVLESSTransports(xhttp: Bool) -> [String] {
        var list = ["tcp", "ws", "grpc", "httpupgrade", "http"]
        if xhttp { list.append("xhttp") }
        return list
    }

    private static func libboxVersionString() -> String {
        #if canImport(Libbox)
            return LibboxVersion()
        #else
            return "unknown"
        #endif
    }

    private struct LinkedExport {
        var present: Bool = false
        var magic: String?
        var apiVersion: Int = 0
        var coreName: String?
        var coreVersion: String?
        var tags: [String] = []
        var capabilityJSON: String?
        var xhttp: Bool?
        var awg: Bool?
        var awgVersions: [String] = []
        var masqueConnectIP: Bool?
        var masqueConnectUDP: Bool?
        var vlessEncryption: Bool?
        var mieru: Bool?
        var hysteria2Obfuscations: [String] = []
        var vlessTransports: [String] = []
        var vlessSecurity: [String] = []
        var supportsHysteria2: Bool?
    }

    private static func readLinkedExports() -> LinkedExport {
        #if canImport(Libbox)
            var out = LinkedExport(present: true)
            out.magic = LibboxVPNDirectCoreMagic()
            out.apiVersion = Int(LibboxVPNDirectCoreAPIVersion())
            out.coreName = LibboxVPNDirectCoreName()
            out.coreVersion = LibboxVPNDirectCoreVersion()
            out.capabilityJSON = LibboxVPNDirectCapabilityJSON()
            let csv = LibboxVPNDirectBuildTagsCSV()
            out.tags = csv.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            out.xhttp = LibboxVPNDirectSupportsXHTTP()
            out.awg = LibboxVPNDirectSupportsAWG()
            out.awgVersions = LibboxVPNDirectAWGVersionsCSV()
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
            out.masqueConnectIP = LibboxVPNDirectSupportsMASQUEConnectIP()
            out.masqueConnectUDP = LibboxVPNDirectSupportsMASQUEConnectUDP()
            out.vlessEncryption = LibboxVPNDirectSupportsVLESSEncryption()
            out.mieru = LibboxVPNDirectSupportsMieru()
            out.hysteria2Obfuscations = LibboxVPNDirectHysteria2ObfuscationsCSV()
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
            if let json = out.capabilityJSON,
               let data = json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                let protocols = obj["protocols"] as? [String: Any] ?? [:]
                let vless = protocols["vless"] as? [String: Any] ?? [:]
                let hysteria2 = protocols["hysteria2"] as? [String: Any] ?? [:]
                out.vlessTransports = (vless["transports"] as? [String]) ?? []
                out.vlessSecurity = (vless["security"] as? [String]) ?? []
                out.supportsHysteria2 = hysteria2["supported"] as? Bool
            }
            return out
        #else
            return LinkedExport()
        #endif
    }

    private struct Stamp {
        var coreName: String?
        var coreVersion: String?
        var tags: [String]
    }

    private static func readVersionStamp() -> Stamp {
        var tags: [String] = []
        var coreVersion: String?
        var coreName: String?

        let candidates: [URL] = [
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("Libbox.xcframework/VPNDirectCore.version"),
            Bundle(for: LibraryMarker.self).bundleURL
                .appendingPathComponent("VPNDirectCore.version"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Libbox.xcframework/VPNDirectCore.version"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Libbox.xcframework/VPNDirectCore.version"),
        ]

        for url in candidates {
            guard FileManager.default.fileExists(atPath: url.path),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            for rawLine in text.split(whereSeparator: \.isNewline) {
                let line = String(rawLine)
                if line.hasPrefix("CORE_VERSION=") {
                    coreVersion = String(line.dropFirst("CORE_VERSION=".count))
                } else if line.hasPrefix("CORE_NAME=") {
                    coreName = String(line.dropFirst("CORE_NAME=".count))
                } else if line.hasPrefix("BUILD_TAGS=") {
                    let value = String(line.dropFirst("BUILD_TAGS=".count))
                    tags = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
            }
            break
        }

        if let envVer = ProcessInfo.processInfo.environment["VPN_DIRECT_CORE_VERSION"], !envVer.isEmpty {
            coreVersion = envVer
        }
        if coreName == nil, coreVersion != nil {
            coreName = "VPNDirectCore"
        }
        return Stamp(coreName: coreName, coreVersion: coreVersion, tags: tags)
    }

    private static func decodeCapabilityJSON(_ raw: String, singBoxVersion: String) -> VPNDirectCoreCapabilities? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let magic = obj["magic"] as? String ?? ""
        let api = (obj["api"] as? Int) ?? (obj["api"] as? NSNumber)?.intValue ?? 0
        guard magic == expectedMagic, api == expectedAPIVersion else {
            return nil
        }

        let protocols = obj["protocols"] as? [String: Any] ?? [:]
        let amnezia = protocols["amneziawg"] as? [String: Any] ?? [:]
        let hysteria2 = protocols["hysteria2"] as? [String: Any] ?? [:]
        let masque = protocols["masque"] as? [String: Any] ?? [:]
        let mieru = protocols["mieru"] as? [String: Any] ?? [:]
        let vless = protocols["vless"] as? [String: Any] ?? [:]
        let transports = obj["transports"] as? [String: Any] ?? [:]

        let hasXHTTP = (obj["xhttp"] as? Bool) ?? (transports["xhttp"] as? Bool) ?? false
        let hasAWG = (obj["awg"] as? Bool) ?? (amnezia["supported"] as? Bool) ?? false
        let awgVersions = (obj["awgVersions"] as? [String]) ?? (amnezia["versions"] as? [String]) ?? []
        let hasMASQUE = (obj["masqueConnectIP"] as? Bool) ?? (masque["connect_ip"] as? Bool) ?? false
        let hasMASQUEUDP = (obj["masqueConnectUDP"] as? Bool) ?? (masque["connect_udp"] as? Bool) ?? false
        let hasVLESSEnc = (obj["vlessEncryption"] as? Bool) ?? (vless["encryption"] as? Bool) ?? false
        let hasMieru = (obj["mieru"] as? Bool) ?? (mieru["supported"] as? Bool) ?? false
        let hysteriaObfs = (obj["hysteria2Obfuscations"] as? [String])
            ?? (hysteria2["obfuscation"] as? [String])
            ?? []
        let hasHysteria2 = (hysteria2["supported"] as? Bool) ?? !hysteriaObfs.isEmpty
        let vlessTransports = (vless["transports"] as? [String]) ?? []
        let vlessSecurity = (vless["security"] as? [String]) ?? []
        let tagsCSV = obj["tags"] as? String ?? ""
        let tags = tagsCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty }

        return VPNDirectCoreCapabilities(
            coreName: (obj["core"] as? String) ?? "VPNDirectCore",
            coreVersion: (obj["version"] as? String) ?? "0.1.0",
            singBoxVersion: (obj["singBox"] as? String) ?? singBoxVersion,
            buildTags: tags,
            abiCompatible: true,
            supportsXHTTP: hasXHTTP,
            supportsAWG: hasAWG,
            amneziaWGVersions: hasAWG ? awgVersions : [],
            supportsMASQUEConnectIP: hasMASQUE,
            supportsMASQUEConnectUDP: hasMASQUEUDP,
            supportsVLESSEncryption: hasVLESSEnc,
            supportsMieru: hasMieru,
            hysteria2Obfuscations: hysteriaObfs,
            vlessTransports: vlessTransports,
            vlessSecurity: vlessSecurity,
            supportsHysteria2: hasHysteria2,
            coreDocument: obj
        )
    }
}

private final class LibraryMarker {}
