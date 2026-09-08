import Foundation
import XCTest
@testable import VPNDirectParsers

final class VMessURIShareLinkTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testHappStyleVMessURIWithEmojiFragment() throws {
        let link =
            "vmess://8e9687fc-a3a7-414a-8676-8e2136797cfe@newrelax.relaxedboy.online:110?encryption=auto&security=none&type=tcp#US 🇺🇸 | @Raydikalx | A27395"
        let node = try VMessShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.protocolID, .vmess)
        XCTAssertEqual(node.server, "newrelax.relaxedboy.online")
        XCTAssertEqual(node.port, 110)
        XCTAssertEqual(node.uuid, "8e9687fc-a3a7-414a-8676-8e2136797cfe")
        XCTAssertEqual(node.security, VPNDirectSecurityID.none)
        XCTAssertEqual(node.attributes["encryption"], "auto")
        XCTAssertTrue(node.name.contains("US"))
        XCTAssertTrue(node.name.contains("Raydikalx"))

        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["type"] as? String, "vmess")
        XCTAssertEqual(outbound["server"] as? String, "newrelax.relaxedboy.online")
        XCTAssertEqual(outbound["server_port"] as? Int, 110)
        XCTAssertEqual(outbound["uuid"] as? String, "8e9687fc-a3a7-414a-8676-8e2136797cfe")
        // Cipher must be auto — not TLS "none" from security=.
        XCTAssertEqual(outbound["security"] as? String, "auto")
        XCTAssertNil(outbound["tls"])
    }

    func testClassicBase64JSONStillWorks() throws {
        let json = #"{"v":"2","ps":"Classic","add":"203.0.113.10","port":"443","id":"8e9687fc-a3a7-414a-8676-8e2136797cfe","aid":"0","scy":"auto","net":"tcp","tls":""}"#
        let b64 = Data(json.utf8).base64EncodedString()
        let node = try VMessShareLinkParser().parseShareLink("vmess://\(b64)")
        XCTAssertEqual(node.server, "203.0.113.10")
        XCTAssertEqual(node.port, 443)
        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["security"] as? String, "auto")
    }
}
