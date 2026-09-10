import CryptoKit
import Foundation
import VPNDirectParsers

// MARK: - Capability probe (mirrors ParserTestSupport)

private let capabilityJSON = """
{"magic":"VPN_DIRECT_CORE","api":1,"xhttp":true,"awg":true,"awgVersions":["2","3.0","3.1"],"masqueConnectIP":true,"vlessEncryption":true,"mieru":true,"hysteria2Obfuscations":["salamander","gecko"],"tags":"with_mieru,with_awg","protocols":{"vless":{"transports":["tcp","ws","grpc","httpupgrade","xhttp"],"security":["none","tls","reality"],"encryption":true},"mieru":{"supported":true},"hysteria2":{"supported":true,"obfuscation":["salamander","gecko"]},"amneziawg":{"supported":true,"versions":["2","3.0","3.1"]},"masque":{"connect_ip":true}}}
"""

private let shareSchemes: Set<String> = [
    "vless", "vmess", "trojan", "ss", "ssr",
    "hysteria", "hysteria2", "hy2", "tuic", "anytls",
    "wireguard", "wg", "awg", "socks", "socks5", "socks4",
    "ssh", "shadowtls",
    "naive", "naive+https", "naive+quic",
    "http-proxy", "https-proxy",
]

// MARK: - CLI

private struct Options {
    var inputPath: String?
    var limit: Int = 50
    var singBoxPath: String?
    var noCheck: Bool = false
    var json: Bool = true
}

private func parseArgs(_ args: [String]) -> Options {
    var opts = Options()
    var i = 0
    while i < args.count {
        let a = args[i]
        switch a {
        case "--input":
            i += 1
            if i < args.count { opts.inputPath = args[i] }
        case "--limit":
            i += 1
            if i < args.count { opts.limit = Int(args[i]) ?? 50 }
        case "--singbox":
            i += 1
            if i < args.count { opts.singBoxPath = args[i] }
        case "--no-check":
            opts.noCheck = true
        case "--json":
            opts.json = true
        case "-h", "--help":
            fputs(
                """
                BattleParse — VPN Direct parser battle CLI

                Usage:
                  BattleParse [--input PATH] [--limit N] [--json] [--singbox PATH] [--no-check]

                Reads PATH or stdin. Always prints one JSON object to stdout.

                """,
                stderr
            )
            exit(0)
        default:
            if a.hasPrefix("-") {
                fputs("unknown option: \(a)\n", stderr)
                exit(2)
            }
        }
        i += 1
    }
    return opts
}

private func readInput(path: String?) throws -> String {
    if let path, path != "-" {
        return try String(contentsOfFile: path, encoding: .utf8)
    }
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .isoLatin1)
        ?? ""
}

private func ensureCapabilities() {
    if ProcessInfo.processInfo.environment["VPN_DIRECT_CAPABILITY_JSON"] == nil {
        setenv("VPN_DIRECT_CAPABILITY_JSON", capabilityJSON, 1)
    }
    _ = VPNDirectCoreCapabilities.probe()
}

// MARK: - Variant classifier

private enum VariantClassifier {
    static func classify(_ node: NormalizedNode) -> String {
        switch node.protocolID {
        case .vless:
            return classifyVLESS(node)
        case .hysteria2:
            return classifyHY2(node)
        case .hysteria:
            return "hysteria"
        case .shadowsocks:
            return classifySS(node)
        case .tuic:
            return "tuic-v5"
        case .amneziawg:
            let ver = node.attributes["amnezia_version"] ?? "2"
            if ver.hasPrefix("3.1") { return "amneziawg-3.1" }
            if ver.hasPrefix("3") { return "amneziawg-3.0" }
            return "amneziawg-2"
        case .masque:
            return "masque-connect-ip"
        case .mieru:
            return classifyMieru(node)
        default:
            return node.protocolID.rawValue
        }
    }

    static func classifyVLESS(_ node: NormalizedNode) -> String {
        let transport = (node.transport?.rawValue
            ?? node.attributes["type"]
            ?? "tcp").lowercased()
        let security = (node.security?.rawValue ?? "none").lowercased()
        let flow = (node.attributes["flow"] ?? "").lowercased()
        let enc = (node.attributes["encryption"] ?? "").lowercased()

        if !enc.isEmpty, enc != "none" {
            return "vless-encryption-pq"
        }
        if transport == "xhttp", security == "reality" {
            return "vless-xhttp-reality"
        }
        if transport == "xhttp" {
            return "vless-xhttp"
        }
        if flow.contains("vision") {
            return "vless-vision"
        }
        switch transport {
        case "ws": return "vless-ws"
        case "grpc": return "vless-grpc"
        case "httpupgrade": return "vless-httpupgrade"
        default: break
        }
        if security == "reality" { return "vless-reality" }
        if security == "tls" { return "vless-tls" }
        return "vless-tcp"
    }

    static func classifyHY2(_ node: NormalizedNode) -> String {
        let obfs = (node.obfuscation?.rawValue ?? node.attributes["obfs"] ?? "").lowercased()
        if obfs == "salamander" { return "hy2-salamander" }
        if obfs == "gecko" { return "hy2-gecko" }
        return "hysteria2"
    }

    static func classifySS(_ node: NormalizedNode) -> String {
        let method = (node.attributes["method"] ?? "").lowercased()
        if method.contains("2022") { return "shadowsocks-2022" }
        return "shadowsocks"
    }

    static func classifyMieru(_ node: NormalizedNode) -> String {
        let transport = (node.attributes["transport"] ?? "TCP").uppercased()
        let pattern = (node.attributes["traffic_pattern"] ?? "").lowercased()
        if pattern.contains("32") { return "mieru-le-32" }
        if pattern.contains("40") { return "mieru-le-40" }
        if pattern.contains("48") { return "mieru-le-48" }
        if pattern.contains("56") { return "mieru-le-56" }
        if pattern.contains("low") || !pattern.isEmpty { return "mieru-le" }
        return transport == "UDP" ? "mieru-udp" : "mieru-tcp"
    }
}

// MARK: - Config hash (no secrets)

private func configHash(type: String, server: String, port: Int, transport: String, security: String) -> String {
    let material = "\(type)|\(server)|\(port)|\(transport)|\(security)"
    let digest = SHA256.hash(data: Data(material.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func hashForNode(_ node: NormalizedNode, outbound: [String: Any]?) -> String {
    let type = (outbound?["type"] as? String)?.lowercased()
        ?? node.protocolID.rawValue
    let server = (outbound?["server"] as? String) ?? node.server
    let port: Int = {
        if let p = outbound?["server_port"] as? Int { return p }
        return node.port
    }()
    let transport: String = {
        if let t = outbound?["transport"] as? [String: Any], let ty = t["type"] as? String {
            return ty.lowercased()
        }
        return node.transport?.rawValue ?? node.attributes["type"] ?? ""
    }()
    let security: String = {
        if let tls = outbound?["tls"] as? [String: Any] {
            if tls["reality"] != nil { return "reality" }
            if (tls["enabled"] as? Bool) == true { return "tls" }
            return "none"
        }
        return node.security?.rawValue ?? ""
    }()
    return configHash(type: type, server: server, port: port, transport: transport, security: security)
}

// MARK: - Failure taxonomy

private enum FailureClass: String {
    case download_error
    case empty_source
    case unsupported_format
    case malformed_input
    case unsupported_protocol
    case unsupported_transport
    case unsupported_field
    case builder_error
    case core_validation_error
    case remote_server_dead
}

private func classifyError(_ error: Error) -> FailureClass {
    if let e = error as? VPNDirectCoreError {
        switch e {
        case .unsupportedTransport:
            return .unsupported_transport
        case .unsupportedSecurity:
            return .unsupported_field
        case .plaintextVLESS:
            return .unsupported_field
        case .unsupportedFeature(let component, _):
            let c = component.lowercased()
            if c.contains("transport") { return .unsupported_transport }
            if c.contains("field") || c.contains("unknown") { return .unsupported_field }
            return .unsupported_protocol
        case .malformedConfig:
            return .malformed_input
        case .coreError, .coreRejected:
            return .core_validation_error
        }
    }
    if let e = error as? VLESSConfigBuilder.VLESSError {
        switch e {
        case .unsupportedFeature:
            return .unsupported_protocol
        case .unsupportedScheme, .invalidURL, .missingUUID, .missingHost, .serializationFailed:
            return .malformed_input
        }
    }
    if error is SubscriptionConfigBuilder.SubscriptionError {
        return .malformed_input
    }
    return .builder_error
}

// MARK: - Outbound wrap + sing-box check (ParserTestSupport twin)

private func wrapOutbound(_ outbound: [String: Any]) throws -> Data {
    let type = (outbound["type"] as? String)?.lowercased() ?? ""
    // Must match production endpoint shape — no legacy outbound rewrite.
    if type == "wireguard" || type == "amneziawg" {
        guard outbound["peers"] != nil, outbound["address"] != nil, outbound["private_key"] != nil else {
            throw VPNDirectCoreError.malformedConfig(
                component: "wireguard",
                detail: "Expected endpoint shape (peers/address/private_key); refusing battle-only rewrite"
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

private func resolveSingBox(explicit: String?) -> String? {
    if let explicit, !explicit.isEmpty,
       FileManager.default.isExecutableFile(atPath: explicit)
    {
        return explicit
    }
    if let env = ProcessInfo.processInfo.environment["SING_BOX"], !env.isEmpty,
       FileManager.default.isExecutableFile(atPath: env)
    {
        return env
    }
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // BattleParse
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // VPNDirectParserPackage
        .deletingLastPathComponent() // tests
        .deletingLastPathComponent() // repo
    let candidates = [
        repoRoot.appendingPathComponent("core/sing-box/sing-box").path,
        "/usr/local/bin/sing-box",
        "/opt/homebrew/bin/sing-box",
    ]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

private func singBoxCheck(configJSON: Data, singBox: String?, label: String) -> (status: String, detail: String?) {
    guard let path = singBox else {
        return ("not_run", "sing-box binary not found")
    }
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("battleparse-\(label)-\(UUID().uuidString).json")
    do {
        try configJSON.write(to: tmp)
    } catch {
        return ("error", "write temp config failed")
    }
    defer { try? FileManager.default.removeItem(at: tmp) }

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: path)
    proc.arguments = ["check", "-c", tmp.path]
    let err = Pipe()
    proc.standardError = err
    proc.standardOutput = Pipe()
    do {
        try proc.run()
        proc.waitUntilExit()
    } catch {
        return ("error", error.localizedDescription)
    }
    if proc.terminationStatus == 0 {
        return ("ok", nil)
    }
    let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ("error", VPNDirectRedactor.redact(msg.trimmingCharacters(in: .whitespacesAndNewlines)))
}

// MARK: - Share-link line filter

private func shareLinkLines(from text: String) -> [String] {
    text
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { line in
            guard !line.isEmpty, !line.hasPrefix("#") else { return false }
            let lower = line.lowercased()
            guard let scheme = lower.split(separator: ":", maxSplits: 1).first.map(String.init) else {
                return false
            }
            return shareSchemes.contains(scheme)
        }
}

// MARK: - Report builder

private func emitJSON(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted]),
          let text = String(data: data, encoding: .utf8)
    else {
        fputs("{\"failure_class\":\"builder_error\",\"detail\":\"json encode failed\"}\n", stdout)
        exit(1)
    }
    print(text)
}

@main
enum BattleParseCLI {
    static func main() {
    let opts = parseArgs(Array(CommandLine.arguments.dropFirst()))
    ensureCapabilities()

    let raw: String
    do {
        raw = try readInput(path: opts.inputPath)
    } catch {
        emitJSON([
            "failure_class": FailureClass.empty_source.rawValue,
            "detail": "failed to read input",
            "kind": NSNull(),
            "nodes": [],
            "totals": ["nodes": 0],
        ])
        exit(1)
    }

    if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        emitJSON([
            "failure_class": FailureClass.empty_source.rawValue,
            "kind": NSNull(),
            "was_base64_decoded": false,
            "nodes": [],
            "totals": [
                "nodes": 0,
                "format_ok": 0,
                "builder_ok": 0,
                "core_ok": 0,
                "failures_by_class": [FailureClass.empty_source.rawValue: 1],
            ],
        ])
        exit(0)
    }

    let detection = VPNDirectContentDetector.detect(text: raw)
    var failuresByClass: [String: Int] = [:]
    func bump(_ c: FailureClass) {
        failuresByClass[c.rawValue, default: 0] += 1
    }

    // sing-box JSON: format detected; stub migrator is no-op → count format_ok, skip full migrate.
    if detection.kind == .singBoxJSON {
        emitJSON([
            "failure_class": NSNull(),
            "kind": detection.kind.rawValue,
            "was_base64_decoded": detection.wasBase64Decoded,
            "format_ok": true,
            "migrate": "skipped_stub",
            "nodes": [],
            "totals": [
                "nodes": 0,
                "limited": 0,
                "format_ok": 1,
                "builder_ok": 0,
                "core_ok": 0,
                "core_not_run": 0,
                "failures_by_class": [:] as [String: Int],
            ],
            "note": "singBoxJSON detected; full migrate skipped (Libbox stub / no node flatten)",
        ])
        exit(0)
    }

    if detection.kind == .unknown {
        bump(.unsupported_format)
        emitJSON([
            "failure_class": FailureClass.unsupported_format.rawValue,
            "kind": detection.kind.rawValue,
            "was_base64_decoded": detection.wasBase64Decoded,
            "nodes": [],
            "totals": [
                "nodes": 0,
                "format_ok": 0,
                "builder_ok": 0,
                "core_ok": 0,
                "failures_by_class": failuresByClass,
            ],
        ])
        exit(0)
    }

    var nodes: [NormalizedNode] = []
    var parseDiagnostics: [String: Any] = [:]

    do {
        switch detection.kind {
        case .uriList, .base64URIList:
            let links = shareLinkLines(from: detection.text)
            let result = VPNDirectParserRegistry.parseShareLinks(links)
            nodes = result.nodes
            parseDiagnostics = [
                "total": result.diagnostics.total,
                "parsed": result.diagnostics.parsed,
                "unsupported": result.diagnostics.unsupported,
                "malformed": result.diagnostics.malformed,
                "unsupported_components": result.diagnostics.unsupportedComponents,
            ]
            if result.diagnostics.malformed > 0 {
                failuresByClass[FailureClass.malformed_input.rawValue, default: 0] += result.diagnostics.malformed
            }
            if result.diagnostics.unsupported > 0 {
                failuresByClass[FailureClass.unsupported_protocol.rawValue, default: 0] += result.diagnostics.unsupported
            }
        case .clashYAML:
            let sub = try ClashYAMLAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .xrayJSON:
            let sub = try XrayJSONAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .mieruJSON:
            let sub = try MieruConfigAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .wireGuardConf:
            let sub = try WireGuardConfAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .openVPNConfig:
            let sub = try OpenVPNConfigAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .openConnectConfig:
            let sub = try OpenConnectConfigAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .tailscaleJSON:
            let sub = try TailscaleConfigAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .masqueConnectUDPJSON:
            let sub = try MasqueConnectUDPAdapter.parse(detection.text)
            nodes = sub.allEndpoints
        case .singBoxJSON, .unknown:
            break
        case .recognizedUnsupported:
            bump(.unsupported_protocol)
            emitJSON([
                "failure_class": FailureClass.unsupported_protocol.rawValue,
                "kind": detection.kind.rawValue,
                "was_base64_decoded": detection.wasBase64Decoded,
                "unsupported_protocol_id": detection.unsupportedProtocolID ?? "unknown",
                "detail": "recognized_but_unsupported",
                "nodes": [],
                "totals": [
                    "nodes": 0,
                    "format_ok": 1,
                    "builder_ok": 0,
                    "core_ok": 0,
                    "failures_by_class": failuresByClass,
                ],
            ])
            exit(0)
        }
    } catch {
        let fc = classifyError(error)
        bump(fc)
        emitJSON([
            "failure_class": fc.rawValue,
            "kind": detection.kind.rawValue,
            "was_base64_decoded": detection.wasBase64Decoded,
            "detail": VPNDirectRedactor.redact(error.localizedDescription),
            "nodes": [],
            "totals": [
                "nodes": 0,
                "format_ok": 0,
                "builder_ok": 0,
                "core_ok": 0,
                "failures_by_class": failuresByClass,
            ],
        ])
        exit(0)
    }

    if nodes.isEmpty {
        bump(.empty_source)
        emitJSON([
            "failure_class": FailureClass.empty_source.rawValue,
            "kind": detection.kind.rawValue,
            "was_base64_decoded": detection.wasBase64Decoded,
            "diagnostics": parseDiagnostics,
            "nodes": [],
            "totals": [
                "nodes": 0,
                "format_ok": 1,
                "builder_ok": 0,
                "core_ok": 0,
                "failures_by_class": failuresByClass,
            ],
        ])
        exit(0)
    }

    let limited = Array(nodes.prefix(max(0, opts.limit)))
    let singBox: String? = opts.noCheck ? nil : resolveSingBox(explicit: opts.singBoxPath)

    var nodeReports: [[String: Any]] = []
    var builderOK = 0
    var coreOK = 0
    var coreNotRun = 0

    for (idx, node) in limited.enumerated() {
        let variant = VariantClassifier.classify(node)
        var entry: [String: Any] = [
            "index": idx,
            "name": VPNDirectRedactor.redact(node.name),
            "protocol": node.protocolID.rawValue,
            "variant": variant,
            "server": node.server,
            "port": node.port,
            "transport": node.transport?.rawValue ?? node.attributes["type"] ?? "",
            "security": node.security?.rawValue ?? "",
        ]

        do {
            let outbound = try UniversalOutboundBuilder.build(from: node)
            builderOK += 1
            entry["config_hash"] = hashForNode(node, outbound: outbound)
            entry["builder"] = "ok"

            if opts.noCheck {
                entry["core_validation"] = "skipped"
                coreNotRun += 1
            } else {
                do {
                    let data = try wrapOutbound(outbound)
                    let check = singBoxCheck(configJSON: data, singBox: singBox, label: "\(idx)-\(variant)")
                    entry["core_validation"] = check.status
                    if let detail = check.detail, !detail.isEmpty {
                        entry["core_detail"] = detail
                    }
                    if check.status == "ok" {
                        coreOK += 1
                    } else if check.status == "not_run" {
                        coreNotRun += 1
                    } else {
                        bump(.core_validation_error)
                        entry["failure_class"] = FailureClass.core_validation_error.rawValue
                    }
                } catch {
                    bump(.builder_error)
                    entry["core_validation"] = "error"
                    entry["failure_class"] = FailureClass.builder_error.rawValue
                    entry["detail"] = VPNDirectRedactor.redact(error.localizedDescription)
                }
            }
        } catch {
            let fc = classifyError(error)
            bump(fc)
            entry["builder"] = "error"
            entry["failure_class"] = fc.rawValue
            entry["config_hash"] = hashForNode(node, outbound: nil)
            entry["detail"] = VPNDirectRedactor.redact(String(describing: error))
            entry["core_validation"] = "not_run"
            coreNotRun += 1
        }

        nodeReports.append(entry)
    }

    emitJSON([
        "failure_class": NSNull(),
        "kind": detection.kind.rawValue,
        "was_base64_decoded": detection.wasBase64Decoded,
        "diagnostics": parseDiagnostics,
        "nodes": nodeReports,
        "totals": [
            "nodes": nodes.count,
            "limited": limited.count,
            "format_ok": 1,
            "builder_ok": builderOK,
            "core_ok": coreOK,
            "core_not_run": coreNotRun,
            "failures_by_class": failuresByClass,
        ],
    ])
    }
}
