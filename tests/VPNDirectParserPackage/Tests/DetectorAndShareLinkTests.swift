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

    func testSSRParsesAsURIListAndBuildsOutbound() throws {
        let link =
            "ssr://bGl2ZS5iaWxpYmlsaWNsb3VkMDEuY29tOjU0MTEyOmF1dGhfYWVzMTI4X3NoYTE6Y2hhY2hhMjAtaWV0ZjpwbGFpbjpUWFkwWlRCUlNGZFFkMlJpUzJsRFJnPT0vP29iZnNwYXJhbT0mcmVtYXJrcz04SiUyQkhyZkNmaDdCSVN5MHhPQzR4TmpZdU1UVTBMakk0TFRBeU16YyUzRCZwcm90b3BhcmFtPQ==#JP"
        let detection = VPNDirectContentDetector.detect(text: link)
        XCTAssertEqual(detection.kind, .uriList)

        let node = try ShadowsocksRShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.protocolID, .shadowsocksr)
        XCTAssertEqual(node.server, "live.bilibilicloud01.com")
        XCTAssertEqual(node.port, 54112)
        XCTAssertEqual(node.attributes["method"], "chacha20-ietf")
        XCTAssertEqual(node.attributes["protocol"], "auth_aes128_sha1")
        XCTAssertEqual(node.attributes["obfs"], "plain")
        XCTAssertEqual(node.attributes["password"], "Mv4e0QHWPwdbKiCF")

        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["type"] as? String, "shadowsocksr")
        XCTAssertEqual(outbound["method"] as? String, "chacha20-ietf")
        XCTAssertEqual(outbound["protocol"] as? String, "auth_aes128_sha1")
        XCTAssertEqual(outbound["obfs"] as? String, "plain")
        XCTAssertEqual(outbound["password"] as? String, "Mv4e0QHWPwdbKiCF")
        // Full `sing-box check` requires a Libbox/binary rebuilt with `with_shadowsocksr`.
        _ = try ParserTestSupport.wrapOutbound(outbound)
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
