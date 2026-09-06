import Foundation

#if canImport(Libbox)
    import Libbox
#endif

/// Runtime feature discovery for VPN Direct Core / Libbox.
/// Builders and UI should query this instead of hardcoding stock-Libbox limits.
///
/// Sources (in priority order):
/// 1. Env overrides (`VPN_DIRECT_BUILD_TAGS`, `VPN_DIRECT_CORE_VERSION`) — tests/CI
/// 2. Sidecar stamp `Libbox.xcframework/VPNDirectCore.version` written by `scripts/build_libbox.sh`
/// 3. Linked Libbox gomobile exports (`LibboxVPNDirect*`) when present in a Core build
/// 4. Conservative stock defaults
public struct VPNDirectCoreCapabilities: Equatable, Sendable {
    public var coreName: String
    public var coreVersion: String
    public var singBoxVersion: String
    public var buildTags: [String]

    public var supportsXHTTP: Bool
    public var supportsAWG: Bool
    public var amneziaWGVersions: [String]
    public var supportsMASQUEConnectIP: Bool
    public var supportsMASQUEConnectUDP: Bool
    public var supportsVLESSEncryption: Bool
    public var supportsMieru: Bool
    public var hysteria2Obfuscations: [String]
    public var vlessTransports: [String]

    public static var current: VPNDirectCoreCapabilities {
        probe()
    }

    public static func probe() -> VPNDirectCoreCapabilities {
        let singBoxVersion = libboxVersionString()
        let stamped = readVersionStamp()
        let exported = readLinkedExports()
        var tags = stamped.tags
        if tags.isEmpty {
            tags = exported.tags
        }

        let isVPNDirectCore = stamped.coreVersion != nil
            || exported.present
            || singBoxVersion.lowercased().contains("-lx")
            || singBoxVersion.lowercased().contains("vpndirect")
            || tags.contains("with_xhttp")

        let hasXHTTP = exported.xhttp ?? (tags.contains("with_xhttp") || isVPNDirectCore)
        let hasAWG = exported.awg ?? (tags.contains("with_awg") || isVPNDirectCore)
        let hasMieru = exported.mieru ?? tags.contains("with_mieru")
        let hasMASQUE = exported.masqueConnectIP ?? isVPNDirectCore
        let hasVLESSEnc = exported.vlessEncryption ?? isVPNDirectCore

        return VPNDirectCoreCapabilities(
            coreName: exported.coreName ?? stamped.coreName ?? (isVPNDirectCore ? "VPNDirectCore" : "Libbox"),
            coreVersion: exported.coreVersion ?? stamped.coreVersion ?? (isVPNDirectCore ? "0.1.0" : "stock"),
            singBoxVersion: singBoxVersion,
            buildTags: tags,
            supportsXHTTP: hasXHTTP,
            supportsAWG: hasAWG,
            amneziaWGVersions: hasAWG ? ["1", "2", "3.0", "3.1"] : [],
            supportsMASQUEConnectIP: hasMASQUE,
            supportsMASQUEConnectUDP: exported.masqueConnectUDP ?? false,
            supportsVLESSEncryption: hasVLESSEnc,
            supportsMieru: hasMieru,
            hysteria2Obfuscations: isVPNDirectCore ? ["salamander", "gecko"] : ["salamander"],
            vlessTransports: {
                var list = ["tcp", "ws", "grpc", "httpupgrade", "http"]
                if hasXHTTP { list.append("xhttp") }
                return list
            }()
        )
    }

    public func jsonObject() -> [String: Any] {
        [
            "core": coreName,
            "version": coreVersion,
            "singBoxVersion": singBoxVersion,
            "buildTags": buildTags,
            "protocols": [
                "vless": [
                    "supported": true,
                    "transports": vlessTransports,
                    "security": ["none", "tls", "reality"],
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
                    "supported": true,
                    "obfuscation": hysteria2Obfuscations,
                ],
            ],
        ]
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
        var coreName: String?
        var coreVersion: String?
        var tags: [String] = []
        var xhttp: Bool?
        var awg: Bool?
        var masqueConnectIP: Bool?
        var masqueConnectUDP: Bool?
        var vlessEncryption: Bool?
        var mieru: Bool?
    }

    /// Calls LibboxVPNDirect* exported by VPN Direct Core Libbox builds.
    private static func readLinkedExports() -> LinkedExport {
        #if canImport(Libbox)
            var out = LinkedExport(present: true)
            out.coreName = LibboxVPNDirectCoreName()
            out.coreVersion = LibboxVPNDirectCoreVersion()
            let csv = LibboxVPNDirectBuildTagsCSV()
            out.tags = csv.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            out.xhttp = LibboxVPNDirectSupportsXHTTP()
            out.awg = LibboxVPNDirectSupportsAWG()
            out.masqueConnectIP = LibboxVPNDirectSupportsMASQUEConnectIP()
            out.masqueConnectUDP = LibboxVPNDirectSupportsMASQUEConnectUDP()
            out.vlessEncryption = LibboxVPNDirectSupportsVLESSEncryption()
            out.mieru = LibboxVPNDirectSupportsMieru()
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

    /// Reads `Libbox.xcframework/VPNDirectCore.version` when present next to the binary bundle.
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

        if let envTags = ProcessInfo.processInfo.environment["VPN_DIRECT_BUILD_TAGS"], !envTags.isEmpty {
            tags = envTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if let envVer = ProcessInfo.processInfo.environment["VPN_DIRECT_CORE_VERSION"], !envVer.isEmpty {
            coreVersion = envVer
        }
        if coreName == nil, coreVersion != nil {
            coreName = "VPNDirectCore"
        }

        return Stamp(coreName: coreName, coreVersion: coreVersion, tags: tags)
    }
}

private final class LibraryMarker {}
