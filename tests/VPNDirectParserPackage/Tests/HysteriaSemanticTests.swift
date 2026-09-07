import Foundation
@testable import VPNDirectParsers
import XCTest

final class HysteriaSemanticTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testHY2OfficialDefaultPortDoesNotInventALPNOrBandwidth() throws {
        let node = try HysteriaShareLinkParser().parseShareLink("hy2://secret@example.com/?sni=edge.example.com#edge")
        XCTAssertEqual(node.protocolID.rawValue, "hysteria2")
        XCTAssertEqual(node.port, 443)
        XCTAssertEqual(node.attributes["sni"], "edge.example.com")
        XCTAssertNil(node.attributes["alpn"])
        XCTAssertNil(node.attributes["up"])
        XCTAssertNil(node.attributes["down"])

        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["server_port"] as? Int, 443)
        XCTAssertNil(outbound["up_mbps"])
        XCTAssertNil(outbound["down_mbps"])
        let tls = try XCTUnwrap(outbound["tls"] as? [String: Any])
        XCTAssertNil(tls["alpn"])
    }

    func testHysteriaV1RequiresExplicitPortAndBandwidth() {
        XCTAssertThrowsError(try HysteriaShareLinkParser().parseShareLink("hysteria://example.com?auth=abc&upmbps=20&downmbps=30"))
        XCTAssertThrowsError(try HysteriaShareLinkParser().parseShareLink("hysteria://example.com:443?auth=abc"))
    }

    func testHysteriaV1PreservesExplicitBandwidth() throws {
        let node = try HysteriaShareLinkParser().parseShareLink("hysteria://example.com:8443?auth=abc&upmbps=17&downmbps=29&peer=sni.example#hy1")
        XCTAssertEqual(node.attributes["up"], "17")
        XCTAssertEqual(node.attributes["down"], "29")
        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["up_mbps"] as? Int, 17)
        XCTAssertEqual(outbound["down_mbps"] as? Int, 29)
    }

    func testHY2GeckoPacketBoundsSurviveRoundTrip() throws {
        let link = "hy2://secret@example.com:443/?obfs=gecko&obfs-password=pw&obfs-min-packet-size=64&obfs-max-packet-size=1200#gecko"
        let node = try HysteriaShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.attributes["obfs"], "gecko")
        XCTAssertEqual(node.attributes["obfs_min_packet_size"], "64")
        XCTAssertEqual(node.attributes["obfs_max_packet_size"], "1200")

        let outbound = try UniversalOutboundBuilder.build(from: node)
        let obfs = try XCTUnwrap(outbound["obfs"] as? [String: Any])
        XCTAssertEqual(obfs["type"] as? String, "gecko")
        XCTAssertEqual(obfs["password"] as? String, "pw")
        XCTAssertEqual(obfs["min_packet_size"] as? Int, 64)
        XCTAssertEqual(obfs["max_packet_size"] as? Int, 1200)
    }
}
