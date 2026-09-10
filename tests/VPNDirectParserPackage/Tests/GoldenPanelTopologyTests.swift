import Foundation
@testable import VPNDirectParsers
import XCTest

/// Remnawave / Marzban / s-ui golden topology fixtures (sanitized).
final class GoldenPanelTopologyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testRemnawaveClashSample() throws {
        let yaml = try ParserTestSupport.readFixture("panels/remnawave/clash_sample.yaml")
        XCTAssertEqual(VPNDirectContentDetector.detect(text: yaml).kind, .clashYAML)
        let sub = try ClashYAMLAdapter.parse(yaml)
        XCTAssertFalse(sub.allEndpoints.isEmpty)
        for node in sub.allEndpoints.prefix(3) {
            let outbound = try UniversalOutboundBuilder.build(from: node)
            let data = try ParserTestSupport.wrapOutbound(outbound)
            _ = try ParserTestSupport.singBoxCheck(data, label: "remnawave-\(node.name)")
        }
    }

    func testMarzbanURIList() throws {
        let raw = try ParserTestSupport.readFixture("panels/marzban/uri_list.txt")
        let detection = VPNDirectContentDetector.detect(text: raw)
        XCTAssertEqual(detection.kind, .uriList)
        let links = raw.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        let parsed = VPNDirectParserRegistry.parseShareLinks(links)
        XCTAssertFalse(parsed.nodes.isEmpty)
        for node in parsed.nodes {
            let outbound = try UniversalOutboundBuilder.build(from: node)
            let data = try ParserTestSupport.wrapOutbound(outbound)
            _ = try ParserTestSupport.singBoxCheck(data, label: "marzban-\(node.protocolID.rawValue)")
        }
    }

    func testSUISingBoxDetected() throws {
        let json = try ParserTestSupport.readFixture("panels/s-ui/singbox.json")
        let detection = VPNDirectContentDetector.detect(text: json)
        XCTAssertEqual(detection.kind, .singBoxJSON)
    }

    func testWireGuardConfAmnezia() throws {
        let conf = try ParserTestSupport.readFixture("panels/amnezia/awg2_sample.conf")
        XCTAssertEqual(VPNDirectContentDetector.detect(text: conf).kind, .wireGuardConf)
        let sub = try WireGuardConfAdapter.parse(conf, amneziaVersion: "2")
        XCTAssertFalse(sub.allEndpoints.isEmpty)
        let outbound = try UniversalOutboundBuilder.build(from: try XCTUnwrap(sub.allEndpoints.first))
        XCTAssertTrue((outbound["type"] as? String) == "wireguard" || (outbound["type"] as? String) == "amneziawg"
            || outbound["amnezia"] != nil || outbound["Jc"] != nil || outbound["jc"] != nil
            || (outbound["type"] as? String) == "wireguard")
        let data = try ParserTestSupport.wrapOutbound(outbound)
        _ = try ParserTestSupport.singBoxCheck(data, label: "awg2")
    }
}
