import Foundation
@testable import VPNDirectParsers
import XCTest

final class RedactionAndFuzzTests: XCTestCase {
    func testRedactorMasksPasswordAndUUID() {
        let sample = #"password=super-secret-token uuid=11111111-1111-1111-1111-111111111111 private_key=AAAA"#
        let redacted = VPNDirectRedactor.redact(sample)
        XCTAssertFalse(redacted.contains("super-secret-token"))
        XCTAssertFalse(redacted.contains("11111111-1111-1111-1111-111111111111"))
        XCTAssertTrue(redacted.contains("***"))
    }

    func testFuzzGarbageRejected() {
        let garbage = [
            "",
            "   ",
            "<html><body>buy vpn</body></html>",
            "{not json",
            "proxies:\n  - broken",
            String(repeating: "A", count: 64),
            "ssr://not-a-real-parser-target",
        ]
        for g in garbage {
            let kind = VPNDirectContentDetector.detect(text: g).kind
            if kind == .uriList || kind == .base64URIList {
                let links = g.split(whereSeparator: \.isNewline).map(String.init)
                let parsed = VPNDirectParserRegistry.parseShareLinks(links)
                XCTAssertEqual(parsed.nodes.count, 0, "garbage should not yield nodes: \(g.prefix(40))")
            } else {
                XCTAssertTrue(
                    kind == .unknown || kind == .clashYAML || kind == .recognizedUnsupported,
                    "unexpected kind \(kind) for \(g.prefix(40))"
                )
                if kind == .clashYAML {
                    XCTAssertThrowsError(try ClashYAMLAdapter.parse(g))
                }
            }
        }
    }

    func testLoopbackShareLinkRejected() {
        let link = "vless://11111111-1111-1111-1111-111111111111@127.0.0.1:443?encryption=none&security=none&type=tcp#loop"
        XCTAssertThrowsError(try VLESSShareLinkParser().parseShareLink(link))
    }

    /// Mutates a seed VLESS URI at 50 random positions / appends garbage — asserts no crash.
    func testPropertyMutatedShareLinks() {
        let base =
            "vless://11111111-1111-1111-1111-111111111111@203.0.113.10:443?encryption=none&security=tls&type=ws&path=%2F&sni=example.com#seed"
        var rng = SeededGenerator(seed: 0xC0FFEE)
        let parser = VLESSShareLinkParser()
        for i in 0 ..< 50 {
            var chars = Array(base)
            let mode = i % 3
            if mode == 0, !chars.isEmpty {
                let idx = Int.random(in: 0 ..< chars.count, using: &rng)
                chars[idx] = Character(UnicodeScalar(UInt8.random(in: 32 ... 126, using: &rng)))
            } else if mode == 1, !chars.isEmpty {
                let idx = Int.random(in: 0 ..< chars.count, using: &rng)
                chars.remove(at: idx)
            } else {
                let junk = (0 ..< Int.random(in: 1 ... 24, using: &rng)).map { _ in
                    Character(UnicodeScalar(UInt8.random(in: 33 ... 126, using: &rng)))
                }
                chars.append(contentsOf: junk)
            }
            let mutated = String(chars)
            do {
                _ = try parser.parseShareLink(mutated)
            } catch {
                // Expected for most mutations — must not crash.
            }
            let links = [mutated]
            _ = VPNDirectParserRegistry.parseShareLinks(links)
        }
    }

    /// Mutates Clash YAML / Xray JSON / WG conf / HY2 URI — asserts no crash + structured outcomes.
    func testPropertyMutatedStructuredPayloads() {
        let clashSeed = """
        proxies:
          - name: a
            type: ss
            server: 203.0.113.10
            port: 8388
            cipher: aes-128-gcm
            password: secret
        proxy-groups:
          - name: AUTO
            type: url-test
            proxies: [a]
        """
        let xraySeed =
            #"{"outbounds":[{"tag":"v","protocol":"vless","settings":{"vnext":[{"address":"203.0.113.10","port":443,"users":[{"id":"11111111-1111-1111-1111-111111111111"}]}]},"streamSettings":{"network":"tcp"}}]}"#
        let wgSeed = """
        [Interface]
        PrivateKey = YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
        Address = 10.0.0.2/32
        [Peer]
        PublicKey = ZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
        Endpoint = 203.0.113.10:51820
        AllowedIPs = 0.0.0.0/0
        """
        let hy2Seed = "hy2://password@203.0.113.10:443?sni=example.com&obfs=salamander&obfs-password=pad#seed"
        var rng = SeededGenerator(seed: 0xBEEF_Cafe)
        let seeds = [clashSeed, xraySeed, wgSeed, hy2Seed]
        for base in seeds {
            for i in 0 ..< 25 {
                var chars = Array(base)
                if !chars.isEmpty {
                    let idx = Int.random(in: 0 ..< chars.count, using: &rng)
                    if i % 2 == 0 {
                        chars[idx] = Character(UnicodeScalar(UInt8.random(in: 32 ... 126, using: &rng)))
                    } else {
                        chars.remove(at: idx)
                    }
                }
                let mutated = String(chars)
                let kind = VPNDirectContentDetector.detect(text: mutated).kind
                switch kind {
                case .clashYAML:
                    _ = try? ClashYAMLAdapter.parse(mutated)
                case .xrayJSON:
                    _ = try? XrayJSONAdapter.parse(mutated)
                case .wireGuardConf:
                    _ = try? WireGuardConfAdapter.parse(mutated)
                default:
                    _ = VPNDirectParserRegistry.parseShareLinks([mutated])
                }
            }
        }
    }
}

/// Deterministic RNG for property-style fuzz without flaky CI.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
