import Foundation
@testable import VPNDirectParsers
import XCTest

/// Shapes taken from intentional public harvest feeds (synthetic credentials only).
final class PublicPoolShareLinkTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testAnyTLSDisableSNIBuilds() throws {
        let link = "anytls://pool-password@203.0.113.50:443?security=tls&type=tcp&insecure=1&disable_sni=true&udp=1#anytls-pool"
        let node = try AnyTLSShareLinkParser().parseShareLink(link)
        let leaf = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(leaf["type"] as? String, "anytls")
        let tls = try XCTUnwrap(leaf["tls"] as? [String: Any])
        XCTAssertEqual(tls["disable_sni"] as? Bool, true)
        XCTAssertEqual(tls["insecure"] as? Bool, true)
        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "anytls-disable-sni")
    }

    func testHY2PasswordWithUnencodedSlash() throws {
        let link = "hy2://pass/with/slash@203.0.113.60:443/?insecure=1&sni=www.example.com&obfs=salamander&obfs-password=obfs-secret#hy2-slash"
        let node = try HysteriaShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.server, "203.0.113.60")
        XCTAssertEqual(node.port, 443)
        XCTAssertEqual(node.attributes["password"], "pass/with/slash")
        let leaf = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(leaf["password"] as? String, "pass/with/slash")
        XCTAssertEqual(leaf["server"] as? String, "203.0.113.60")
        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "hy2-slash-password")
    }

    func testTrojanWSPathAndCipherSuitesAliases() throws {
        let link = """
        trojan://pool-pass@203.0.113.70:443?allowInsecure=1&sni=cdn.example.com&\
        ws=1&wspath=%2Fimages&cs=TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384#trojan-pool
        """.replacingOccurrences(of: "\n", with: "")
        let node = try TrojanShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.attributes["path"], "/images")
        XCTAssertEqual(node.attributes["type"], "ws")
        let leaf = try UniversalOutboundBuilder.build(from: node)
        let transport = try XCTUnwrap(leaf["transport"] as? [String: Any])
        XCTAssertEqual(transport["type"] as? String, "ws")
        let tls = try XCTUnwrap(leaf["tls"] as? [String: Any])
        let suites = try XCTUnwrap(tls["cipher_suites"] as? [String])
        XCTAssertTrue(suites.contains("TLS_AES_128_GCM_SHA256"))
        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "trojan-wspath-cs")
    }
}
