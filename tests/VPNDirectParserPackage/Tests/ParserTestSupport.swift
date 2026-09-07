import Foundation
@testable import VPNDirectParsers
import XCTest

enum ParserTestSupport {
    static let fixtureRoot: URL = {
        // tests/VPNDirectParserPackage/Tests → repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // VPNDirectParserPackage
            .deletingLastPathComponent() // tests
            .appendingPathComponent("fixtures")
    }()

    static let repoRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    /// Full-feature capability probe for builder paths (XHTTP, Mieru, AWG, …).
    static let capabilityJSON = """
    {"magic":"VPN_DIRECT_CORE","api":1,"xhttp":true,"awg":true,"awgVersions":["2","3.0","3.1"],"masqueConnectIP":true,"vlessEncryption":true,"mieru":true,"hysteria2Obfuscations":["salamander","gecko"],"tags":"with_mieru,with_awg","protocols":{"vless":{"transports":["tcp","ws","grpc","httpupgrade","xhttp"],"security":["none","tls","reality"],"encryption":true},"mieru":{"supported":true},"hysteria2":{"supported":true,"obfuscation":["salamander","gecko"]},"amneziawg":{"supported":true,"versions":["2","3.0","3.1"]},"masque":{"connect_ip":true}}}
    """

    static func installCapabilities() {
        setenv("VPN_DIRECT_CAPABILITY_JSON", capabilityJSON, 1)
        _ = VPNDirectCoreCapabilities.probe()
    }

    static func readFixture(_ relative: String) throws -> String {
        let url = fixtureRoot.appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func wrapOutbound(_ outbound: [String: Any]) throws -> Data {
        let type = (outbound["type"] as? String)?.lowercased() ?? ""
        // Production builder already emits Core endpoint shape for WireGuard/AWG.
        // Do not rewrite legacy outbound fields here — that masked production bugs.
        if type == "wireguard" || type == "amneziawg" {
            guard outbound["peers"] != nil, outbound["address"] != nil, outbound["private_key"] != nil else {
                throw VPNDirectCoreError.malformedConfig(
                    component: "wireguard",
                    detail: "Expected endpoint shape (peers/address/private_key); refusing test-only rewrite"
                )
            }
            let cfg: [String: Any] = [
                "log": ["level": "warn"],
                "endpoints": [outbound],
                "inbounds": [
                    ["type": "socks", "tag": "in", "listen": "127.0.0.1", "listen_port": 0],
                ],
                "outbounds": [["type": "direct", "tag": "direct"]],
            ]
            return try JSONSerialization.data(withJSONObject: cfg, options: [.sortedKeys])
        }
        let cfg: [String: Any] = [
            "log": ["level": "warn"],
            "inbounds": [
                ["type": "socks", "tag": "in", "listen": "127.0.0.1", "listen_port": 0],
            ],
            "outbounds": [outbound, ["type": "direct", "tag": "direct"]],
        ]
        return try JSONSerialization.data(withJSONObject: cfg, options: [.sortedKeys])
    }

    /// Runs `sing-box check` when a binary is available (PATH, core/sing-box, or SKIP).
    @discardableResult
    static func singBoxCheck(_ configJSON: Data, label: String) throws -> Bool {
        if ProcessInfo.processInfo.environment["VPN_DIRECT_SKIP_SINGBOX_CHECK"] == "1" {
            return false
        }
        let candidates = [
            repoRoot.appendingPathComponent("core/sing-box/sing-box").path,
            "/usr/local/bin/sing-box",
            "/opt/homebrew/bin/sing-box",
        ]
        let path = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? (ProcessInfo.processInfo.environment["SING_BOX"] ?? "")
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            // Soft-skip: parser/builder still asserted; CI check_parser_execution covers binary check.
            return false
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("vpnd-\(label)-\(UUID().uuidString).json")
        try configJSON.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["check", "-c", tmp.path]
        let err = Pipe()
        proc.standardError = err
        proc.standardOutput = Pipe()
        try proc.run()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 0, "sing-box check failed for \(label): \(String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")")
        return true
    }
}
