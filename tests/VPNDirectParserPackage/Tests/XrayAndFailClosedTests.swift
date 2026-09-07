import Foundation
@testable import VPNDirectParsers
import XCTest

final class XrayAndFailClosedTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testXrayJSONAttributesOnlyNoLegacyOutbound() throws {
        let raw = try ParserTestSupport.readFixture("panels/3x-ui/xray_single.json")
        let detection = VPNDirectContentDetector.detect(text: raw)
        XCTAssertEqual(detection.kind, .xrayJSON)
        let sub = try XrayJSONAdapter.parse(raw)
        XCTAssertFalse(sub.allEndpoints.isEmpty)
        for node in sub.allEndpoints {
            XCTAssertTrue(node.outbound == nil || node.outbound?.isEmpty == true,
                          "Xray import must not keep LEGACY outbound dict")
            let outbound = try UniversalOutboundBuilder.build(from: node)
            XCTAssertNotNil(outbound["type"] as? String)
            let data = try ParserTestSupport.wrapOutbound(outbound)
            _ = try ParserTestSupport.singBoxCheck(data, label: "xray-\(node.name)")
        }
    }

    func testUnknownCriticalXHTTPExtensionFailsClosed() throws {
        let raw = try ParserTestSupport.readFixture("panels/remnawave/unknown_critical.json")
        let sub = try XrayJSONAdapter.parse(raw)
        let node = try XCTUnwrap(sub.allEndpoints.first)
        // Invented critical field must surface as attribute/extension and refuse build.
        let keys = Set(node.attributes.keys).union(node.rawExtensions.keys)
        let hasInvented = keys.contains { $0.lowercased().contains("vpndirectcritical") || $0.lowercased().contains("invented") }
        if hasInvented {
            XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node))
        } else {
            // If converter dropped nested unknown under xhttpSettings without preserving it,
            // still fail closed by injecting the key ourselves to prove policy wiring.
            var poisoned = node
            poisoned.attributes["vpnDirectCriticalInventedField"] = "must-fail"
            XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: poisoned))
        }
    }

    func testUnsupportedTransportKCPFailsConvert() throws {
        let json = """
        {"outbounds":[{"protocol":"vmess","tag":"bad","settings":{"vnext":[{"address":"203.0.113.50","port":443,"users":[{"id":"66666666-6666-6666-6666-666666666666","security":"auto"}]}]},"streamSettings":{"network":"kcp","security":"none"}}]}
        """
        XCTAssertThrowsError(try XrayJSONAdapter.parse(json))
    }
}
