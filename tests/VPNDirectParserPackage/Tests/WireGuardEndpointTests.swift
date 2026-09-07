import Foundation
@testable import VPNDirectParsers
import XCTest

final class WireGuardEndpointTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testMultiPeerConfPreservesAllPeersAndEndpointShape() throws {
        let text = try ParserTestSupport.readFixture("wireguard/multi_peer.conf")
        let sub = try WireGuardConfAdapter.parse(text)
        XCTAssertEqual(sub.locations.count, 1)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.protocolID, .wireguard)
        let options = try XCTUnwrap(node.wireguardEndpoint)
        XCTAssertEqual(options.peers.count, 2)
        XCTAssertEqual(options.peers[0].allowedIPs, ["0.0.0.0/0"])
        XCTAssertEqual(options.peers[1].allowedIPs, ["::/0"])
        XCTAssertEqual(options.peers[1].persistentKeepaliveInterval, 15)

        let leaf = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(leaf["type"] as? String, "wireguard")
        XCTAssertNotNil(leaf["peers"])
        XCTAssertNotNil(leaf["address"])
        XCTAssertNil(leaf["server"])
        XCTAssertNil(leaf["peer_public_key"])
        XCTAssertNil(leaf["local_address"])

        let peers = try XCTUnwrap(leaf["peers"] as? [[String: Any]])
        XCTAssertEqual(peers.count, 2)
        XCTAssertEqual(peers[0]["address"] as? String, "203.0.113.10")
        XCTAssertEqual(peers[0]["port"] as? Int, 51820)
        XCTAssertEqual(peers[1]["address"] as? String, "203.0.113.11")
        XCTAssertEqual(peers[1]["port"] as? Int, 51821)

        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "wg-multi")
    }

    func testAWG2InfersVersionAndKeepsIAndSFields() throws {
        let text = try ParserTestSupport.readFixture("wireguard/awg2_full.conf")
        let sub = try WireGuardConfAdapter.parse(text)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.protocolID, .amneziawg)
        let options = try XCTUnwrap(node.wireguardEndpoint)
        XCTAssertEqual(options.amneziaVersion, "2")
        XCTAssertEqual(options.s3, 30)
        XCTAssertEqual(options.s4, 40)
        XCTAssertEqual(options.i1, "<b 0x01>")
        XCTAssertEqual(options.i5, "<b 0x02>")

        let leaf = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(leaf["jc"] as? Int, 4)
        XCTAssertEqual(leaf["s3"] as? Int, 30)
        XCTAssertEqual(leaf["i1"] as? String, "<b 0x01>")
        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "awg2")
    }

    func testAWG30InfersFromHeaderProtection() throws {
        let text = try ParserTestSupport.readFixture("wireguard/awg3_0.conf")
        let sub = try WireGuardConfAdapter.parse(text)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.protocolID, .amneziawg)
        XCTAssertEqual(node.wireguardEndpoint?.amneziaVersion, "3.0")
        let leaf = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(leaf["header_protection_key"] as? String, "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDE=")
        XCTAssertEqual(leaf["content_padding_addition"] as? String, "0-64")
        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "awg30")
    }

    func testAWG31InfersFromRandomTrailers() throws {
        let text = try ParserTestSupport.readFixture("wireguard/awg3_1.conf")
        let sub = try WireGuardConfAdapter.parse(text)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.wireguardEndpoint?.amneziaVersion, "3.1")
        let leaf = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(leaf["random_trailers"] as? Bool, true)
        XCTAssertEqual(leaf["disable_cookies"] as? Bool, true)
        let data = try ParserTestSupport.wrapOutbound(leaf)
        _ = try ParserTestSupport.singBoxCheck(data, label: "awg31")
    }

    func testVersionTautologyGonePlainWG() throws {
        let text = try ParserTestSupport.readFixture("panels/wg-easy/wireguard_peer.conf")
        let sub = try WireGuardConfAdapter.parse(text)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.protocolID, .wireguard)
        XCTAssertNil(node.attributes["amnezia_version"])
    }

    func testRefuseLegacyOutboundWrapInTests() throws {
        let legacy: [String: Any] = [
            "type": "wireguard",
            "tag": "bad",
            "server": "203.0.113.1",
            "server_port": 51820,
            "private_key": "x",
            "peer_public_key": "y",
            "local_address": ["10.0.0.2/32"],
        ]
        XCTAssertThrowsError(try ParserTestSupport.wrapOutbound(legacy))
    }
}
