import Foundation
import XCTest
@testable import VPNDirectParsers

final class TrojanURIShareLinkTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testCloudflareWSEarlyDataPathAndEmojiFragment() throws {
        let link =
            "trojan://0000@masterserver1-masterserver1-masterserver1-masterserver1.cowebag581.workers.dev:2087?security=tls&sni=masterserver1-masterserver1-masterserver1-masterserver1.cowebag581.workers.dev&fp=chrome&type=ws&host=masterserver1-masterserver1-masterserver1-masterserver1.cowebag581.workers.dev&path=/?ed=2560#CA 🇨🇦 | @Raydikalx | CCEE9E"
        let node = try TrojanShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.protocolID, .trojan)
        XCTAssertEqual(node.port, 2087)
        XCTAssertEqual(node.attributes["password"], "0000")
        XCTAssertEqual(node.attributes["path"], "/")
        XCTAssertEqual(node.attributes["max_early_data"], "2560")
        XCTAssertEqual(node.attributes["early_data_header_name"], "Sec-WebSocket-Protocol")
        XCTAssertTrue(node.name.contains("CA"))
        XCTAssertTrue(node.name.contains("Raydikalx"))

        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["type"] as? String, "trojan")
        let transport = try XCTUnwrap(outbound["transport"] as? [String: Any])
        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/")
        XCTAssertEqual(transport["max_early_data"] as? Int, 2560)
        let tls = try XCTUnwrap(outbound["tls"] as? [String: Any])
        XCTAssertEqual(tls["enabled"] as? Bool, true)
        let utls = try XCTUnwrap(tls["utls"] as? [String: Any])
        XCTAssertEqual(utls["fingerprint"] as? String, "chrome")
    }
}
