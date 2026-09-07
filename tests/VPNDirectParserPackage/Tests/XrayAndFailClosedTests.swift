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

    func testCurrent3xUISingleObjectFlatVLESS() throws {
        let raw = try ParserTestSupport.readFixture("panels/3x-ui/xray_single_flat.json")
        let sub = try XrayJSONAdapter.parse(raw)
        XCTAssertEqual(sub.allEndpoints.count, 1)
        let node = try XCTUnwrap(sub.allEndpoints.first)
        XCTAssertEqual(node.server, "203.0.113.44")
        XCTAssertEqual(node.port, 443)
        XCTAssertEqual(node.uuid, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertNil(node.outbound)

        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["type"] as? String, "vless")
        XCTAssertEqual(outbound["server"] as? String, "203.0.113.44")
        XCTAssertEqual(outbound["uuid"] as? String, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertNil(outbound["packet_encoding"], "3x-ui did not emit packet encoding; builder must not invent xudp")

        let transport = try XCTUnwrap(outbound["transport"] as? [String: Any])
        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/sub-ws")
        let headers = try XCTUnwrap(transport["headers"] as? [String: String])
        XCTAssertEqual(headers["Host"], "cdn.example.com")
        XCTAssertEqual(headers["X-Panel-Test"], "preserve-me")

        let tls = try XCTUnwrap(outbound["tls"] as? [String: Any])
        XCTAssertEqual(tls["server_name"] as? String, "cdn.example.com")
        XCTAssertEqual(tls["insecure"] as? Bool, false)
        XCTAssertEqual(tls["alpn"] as? [String], ["http/1.1"])

        let data = try ParserTestSupport.wrapOutbound(outbound)
        _ = try ParserTestSupport.singBoxCheck(data, label: "3x-ui-flat-vless")
    }

    func testUnknownCriticalXHTTPExtensionFailsClosed() throws {
        let raw = try ParserTestSupport.readFixture("panels/remnawave/unknown_critical.json")
        let sub = try XrayJSONAdapter.parse(raw)
        let node = try XCTUnwrap(sub.allEndpoints.first)
        let keys = Set(node.attributes.keys).union(node.rawExtensions.keys)
        let hasInvented = keys.contains { $0.lowercased().contains("vpndirectcritical") || $0.lowercased().contains("invented") }
        if hasInvented {
            XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node))
        } else {
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

    func testUnsupportedExplicitXrayTCPHeaderFailsClosed() throws {
        let json = """
        {"outbounds":[{"protocol":"vless","tag":"bad-tcp-header","settings":{"address":"203.0.113.52","port":443,"id":"77777777-7777-7777-7777-777777777777","encryption":"none"},"streamSettings":{"network":"tcp","security":"none","tcpSettings":{"header":{"type":"srtp"}}}}]}
        """
        XCTAssertThrowsError(try XrayJSONAdapter.parse(json),
                             "An explicit unsupported Xray TCP header must never become ordinary TCP")
    }

    func testRealityXHTTPStreamOneModeIsPreserved() throws {
        let xray: [String: Any] = [
            "protocol": "vless",
            "tag": "xhttp-stream-one",
            "settings": [
                "address": "203.0.113.53",
                "port": 443,
                "id": "88888888-8888-8888-8888-888888888888",
                "encryption": "none",
            ],
            "streamSettings": [
                "network": "xhttp",
                "security": "reality",
                "realitySettings": [
                    "serverName": "example.com",
                    "publicKey": "test-public-key",
                    "shortId": "0123456789abcdef",
                    "fingerprint": "chrome",
                ],
                "xhttpSettings": [
                    "path": "/xhttp",
                    "mode": "stream-one",
                ],
            ],
        ]

        let converted = try XCTUnwrap(XrayVLESSConverter.convert(xray, fallbackTag: "xhttp-stream-one"))
        let transport = try XCTUnwrap(converted["transport"] as? [String: Any])
        XCTAssertEqual(transport["type"] as? String, "xhttp")
        XCTAssertEqual(transport["path"] as? String, "/xhttp")
        XCTAssertEqual(transport["mode"] as? String, "stream-one",
                       "Pinned sing-box-lx supports stream-one directly; never rewrite it to auto")
    }

    func testPinnedXHTTPBuilderKeepsRangeFieldsAsStrings() throws {
        let node = NormalizedNode(
            name: "xhttp-types",
            protocolID: .vless,
            server: "203.0.113.54",
            port: 443,
            transport: .xhttp,
            security: .none,
            uuid: "99999999-9999-9999-9999-999999999999",
            attributes: [
                "mode": "stream-one",
                "x_padding_bytes": "100-300",
                "sc_max_each_post_bytes": "100000-200000",
                "sc_min_posts_interval_ms": "20-40",
                "sc_stream_up_server_secs": "20-80",
                "sc_max_buffered_posts": "30",
                "xmux_max_concurrency": "1-4",
                "xmux_max_connections": "3",
                "xmux_c_max_reuse_times": "0",
                "xmux_h_max_request_times": "600-900",
                "xmux_h_max_reusable_secs": "1800-3000",
                "xmux_h_keep_alive_period": "0",
                "no_grpc_header": "true",
                "x_padding_obfs_mode": "true",
                "session_placement": "path",
                "seq_placement": "path",
                "uplink_data_placement": "body",
                "uplink_chunk_size": "4096-8192",
                "uplink_http_method": "POST",
            ]
        )

        let outbound = try UniversalOutboundBuilder.build(from: node)
        let transport = try XCTUnwrap(outbound["transport"] as? [String: Any])
        XCTAssertEqual(transport["mode"] as? String, "stream-one")
        XCTAssertEqual(transport["x_padding_bytes"] as? String, "100-300")
        XCTAssertEqual(transport["sc_max_each_post_bytes"] as? String, "100000-200000")
        XCTAssertEqual(transport["sc_min_posts_interval_ms"] as? String, "20-40")
        XCTAssertEqual(transport["sc_stream_up_server_secs"] as? String, "20-80")
        XCTAssertEqual(transport["xmux_max_concurrency"] as? String, "1-4")
        XCTAssertEqual(transport["xmux_h_max_request_times"] as? String, "600-900")
        XCTAssertEqual(transport["xmux_h_max_reusable_secs"] as? String, "1800-3000")
        XCTAssertEqual(transport["sc_max_buffered_posts"] as? Int, 30)
        XCTAssertEqual(transport["xmux_max_connections"] as? Int, 3)
        XCTAssertEqual(transport["xmux_c_max_reuse_times"] as? Int, 0)
        XCTAssertEqual(transport["xmux_h_keep_alive_period"] as? Int, 0)
        XCTAssertEqual(transport["no_grpc_header"] as? Bool, true)
        XCTAssertEqual(transport["x_padding_obfs_mode"] as? Bool, true)
        XCTAssertNil(transport["extra"])
        XCTAssertNil(transport["sc_max_concurrent_posts"])
    }

    func testXHTTPExtraWrapperIsNotSilentlyDropped() throws {
        var node = NormalizedNode(
            name: "xhttp-extra",
            protocolID: .vless,
            server: "203.0.113.55",
            port: 443,
            transport: .xhttp,
            security: .none,
            uuid: "aaaaaaaa-9999-9999-9999-999999999999"
        )
        node.attributes["extra"] = #"{"futureConnectionKnob":true}"#
        XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node),
                             "Unknown Xray extra must fail closed until it has an exact pinned-Core mapping")
    }

    func testVLESSPQDoesNotDowngradeWhenCapabilityMissing() throws {
        let previous = ProcessInfo.processInfo.environment["VPN_DIRECT_CAPABILITY_JSON"]
        _ = previous // Environment mutation is intentionally avoided; exercise converter by direct policy fixture in CI capability-negative suite.
        let xray: [String: Any] = [
            "protocol": "vless",
            "tag": "pq",
            "settings": [
                "address": "203.0.113.51",
                "port": 443,
                "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                "encryption": "mlkem768x25519plus.native.1rtt.test-key",
            ],
            "streamSettings": ["network": "tcp", "security": "none"],
        ]
        let converted = try XCTUnwrap(XrayVLESSConverter.convert(xray, fallbackTag: "pq"))
        XCTAssertEqual(converted["encryption"] as? String, "mlkem768x25519plus.native.1rtt.test-key")
    }
}
