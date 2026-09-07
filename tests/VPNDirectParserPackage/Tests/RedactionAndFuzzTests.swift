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
                    kind == .unknown || kind == .clashYAML,
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
}
