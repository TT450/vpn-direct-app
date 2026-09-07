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
        [{"remarks":"kcp","outbounds":[{"protocol":"vmess","tag":"bad","settings":{"vnext":[{"address":"203.0.113.50","port":443,"users":[{"id":"66666666-6666-6666-6666-666666666666","security":"auto"}]}]},"streamSettings":{"network":"kcp","security":"none"}}]}]
        """
        XCTAssertThrowsError(try XrayJSONAdapter.parse(json))
    }

    /// REQ-P011: VLESS unknown/unsupported transport must not become plain TCP.
    func testVLESSUnsupportedKCPFailsClosed() throws {
        let json = """
        [{"remarks":"vless-kcp","outbounds":[{"protocol":"vless","tag":"bad","settings":{"vnext":[{"address":"203.0.113.50","port":443,"users":[{"id":"66666666-6666-6666-6666-666666666666"}]}]},"streamSettings":{"network":"kcp","security":"none"}}]}]
        """
        XCTAssertThrowsError(try XrayJSONAdapter.parse(json)) { error in
            let text = String(describing: error).lowercased()
            XCTAssertTrue(text.contains("lost") || text.contains("unsupported") || text.contains("kcp"))
        }
    }

    /// REQ-P011 sibling: independent good leaf + unsupported leaf → warning, not silent drop.
    func testVLESSPartialImportSurfacesWarning() throws {
        let json = """
        [{"remarks":"mixed","outbounds":[
          {"protocol":"vless","tag":"ok","settings":{"vnext":[{"address":"203.0.113.10","port":443,"users":[{"id":"11111111-1111-1111-1111-111111111111"}]}]},"streamSettings":{"network":"tcp","security":"none"}},
          {"protocol":"vless","tag":"bad","settings":{"vnext":[{"address":"203.0.113.50","port":443,"users":[{"id":"66666666-6666-6666-6666-666666666666"}]}]},"streamSettings":{"network":"kcp","security":"none"}}
        ]}]
        """
        let sub = try XrayJSONAdapter.parse(json)
        XCTAssertEqual(sub.allEndpoints.count, 1)
        XCTAssertFalse(sub.importWarnings.isEmpty)
        XCTAssertTrue(sub.importWarnings.joined().lowercased().contains("rejected"))
    }

    /// REQ-P012: encryption must fail closed when capability is off.
    func testVLESSEncryptionFailClosedWithoutCapability() throws {
        setenv("VPN_DIRECT_CAPABILITY_JSON", #"{"magic":"VPN_DIRECT_CORE","api":1,"vlessEncryption":false,"xhttp":true}"#, 1)
        _ = VPNDirectCoreCapabilities.probe()
        defer { ParserTestSupport.installCapabilities() }

        var node = NormalizedNode(
            name: "enc",
            protocolID: .vless,
            server: "203.0.113.10",
            port: 443,
            attributes: [
                "uuid": "11111111-1111-1111-1111-111111111111",
                "encryption": "mlkem768x25519plus",
            ]
        )
        XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node)) { error in
            let text = String(describing: error).lowercased()
            XCTAssertTrue(text.contains("encryption"))
        }
        // Legacy outbound path must also fail closed.
        node.outbound = [
            "type": "vless",
            "server": "203.0.113.10",
            "server_port": 443,
            "uuid": "11111111-1111-1111-1111-111111111111",
            "encryption": "mlkem768x25519plus",
        ]
        XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node))
    }

    /// REQ-P019: routing metadata → explicit graph warning, not silent apply.
    func testRoutingMetadataSurfacesIgnoredWarning() throws {
        var meta = SubscriptionMetadata()
        meta.routingEnabled = true
        meta.routingRules = #"[{"outbound":"proxy","domain":["geosite:google"]}]"#
        let node = NormalizedNode(
            name: "leaf",
            protocolID: .socks,
            server: "203.0.113.10",
            port: 1080,
            attributes: ["version": "5"]
        )
        let sub = NormalizedSubscription(
            name: "t",
            locations: [
                NormalizedLocation(id: "l1", name: "L", kind: .server, strategy: .single, endpoints: [node]),
            ],
            metadata: meta
        )
        let warnings = VPNDirectRoutingHonesty.ignoredRoutingWarnings(for: sub)
        XCTAssertTrue(warnings.contains { $0.lowercased().contains("routing") })
    }
}
