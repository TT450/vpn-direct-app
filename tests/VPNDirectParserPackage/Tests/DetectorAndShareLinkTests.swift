import Foundation
@testable import VPNDirectParsers
import XCTest

final class DetectorAndShareLinkTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testDetectURIListAndParsePanelRawLinks() throws {
        let raw = try ParserTestSupport.readFixture("panels/3x-ui/raw_links.txt")
        let detection = VPNDirectContentDetector.detect(text: raw)
        XCTAssertEqual(detection.kind, .uriList)

        let links = raw.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        let parsed = VPNDirectParserRegistry.parseShareLinks(links)
        XCTAssertGreaterThanOrEqual(parsed.nodes.count, 4)
        XCTAssertEqual(parsed.diagnostics.malformed, 0)

        for node in parsed.nodes {
            let outbound = try UniversalOutboundBuilder.build(from: node)
            XCTAssertNotNil(outbound["type"] as? String)
            XCTAssertNil(node.outbound, "share-link path must stay attributes-only")
            let data = try ParserTestSupport.wrapOutbound(outbound)
            _ = try ParserTestSupport.singBoxCheck(data, label: node.protocolID.rawValue)
        }
    }

    func testDetectClashNestedOpts() throws {
        let yaml = try ParserTestSupport.readFixture("regression/clash/clash_reality_ws.yaml")
        let detection = VPNDirectContentDetector.detect(text: yaml)
        XCTAssertEqual(detection.kind, .clashYAML)
        let sub = try ClashYAMLAdapter.parse(yaml)
        XCTAssertFalse(sub.allEndpoints.isEmpty)
        let node = try XCTUnwrap(sub.allEndpoints.first)
        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["type"] as? String, "vless")
        let data = try ParserTestSupport.wrapOutbound(outbound)
        _ = try ParserTestSupport.singBoxCheck(data, label: "clash-reality-ws")
    }

    func testDetectMieruAndBuild() throws {
        let json = try ParserTestSupport.readFixture("regression/mieru/mieru_profile.json")
        let detection = VPNDirectContentDetector.detect(text: json)
        XCTAssertEqual(detection.kind, .mieruJSON)
        let sub = try MieruConfigAdapter.parse(json)
        XCTAssertEqual(sub.allEndpoints.count, 1)
        let outbound = try UniversalOutboundBuilder.build(from: try XCTUnwrap(sub.allEndpoints.first))
        XCTAssertEqual(outbound["type"] as? String, "mieru")
        XCTAssertEqual(outbound["transport"] as? String, "TCP")
        let data = try ParserTestSupport.wrapOutbound(outbound)
        _ = try ParserTestSupport.singBoxCheck(data, label: "mieru")
    }

    func testSSRDoesNotClassifyAsURIList() {
        let text = "ssr://YWFhYmJiY2NjZGRkZWVlZg"
        let detection = VPNDirectContentDetector.detect(text: text)
        // SSR is recognized as intentionally unsupported — never misclassified as URI list.
        XCTAssertEqual(detection.kind, .recognizedUnsupported)
        XCTAssertEqual(detection.unsupportedProtocolID, "ssr")
    }

    func testBase64URIListFromPanel() throws {
        let b64 = try ParserTestSupport.readFixture("panels/3x-ui/base64.txt")
        let detection = VPNDirectContentDetector.detect(text: b64.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertTrue(detection.kind == .base64URIList || detection.kind == .uriList)
        XCTAssertTrue(detection.wasBase64Decoded || detection.kind == .uriList)
    }

    /// REQ-P061: Hiddify-style comment metadata before URI list must not break detection.
    func testHiddifyMetadataPrefixURIList() throws {
        let raw = try ParserTestSupport.readFixture("panels/hiddify/metadata_prefix_uri_list.txt")
        let detection = VPNDirectContentDetector.detect(text: raw)
        XCTAssertEqual(detection.kind, .uriList)
        let links = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        let parsed = VPNDirectParserRegistry.parseShareLinks(links)
        XCTAssertEqual(parsed.nodes.count, 1)
        XCTAssertEqual(parsed.nodes.first?.protocolID, .vless)
    }
}
