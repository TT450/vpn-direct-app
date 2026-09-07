import Foundation
import XCTest
@testable import VPNDirectParsers

final class RemnawaveHTTPClassifierTests: XCTestCase {
    func testDeviceLimitFromHeaders() {
        let headers = [
            "x-hwid-max-devices-reached": "true",
            "x-hwid-device-limit": "3",
            "x-hwid-device-used": "3",
        ]
        let c = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
            statusCode: 403,
            headers: headers,
            body: ""
        )
        XCTAssertEqual(c.category, .deviceLimitReached)
        XCTAssertEqual(c.responseType, .block)
        XCTAssertFalse(c.retryable)
    }

    func testHTTP451() {
        let c = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
            statusCode: 451,
            headers: [:],
            body: "unavailable"
        )
        XCTAssertEqual(c.category, .unavailableForLegalReasons)
        XCTAssertEqual(c.responseType, .status451)
    }

    func testHTTP404() {
        let c = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
            statusCode: 404,
            headers: [:],
            body: "missing"
        )
        XCTAssertEqual(c.category, .notFound)
        XCTAssertEqual(c.responseType, .status404)
    }

    func testGeneric403WithoutEvidenceIsHttpErrorNotInventedPanel() {
        let c = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
            statusCode: 403,
            headers: [:],
            body: "<html>Forbidden</html>"
        )
        // HTML browser takes precedence.
        XCTAssertEqual(c.category, .browserPayload)
        XCTAssertEqual(c.responseType, .browser)
    }

    func testGeneric403PlainWithoutEvidence() {
        let c = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
            statusCode: 403,
            headers: [:],
            body: "forbidden"
        )
        XCTAssertEqual(c.category, .httpError)
        XCTAssertTrue(c.evidence.contains("no_panel_evidence"))
    }

    func testExpiredHeader() {
        let c = VPNDirectSubscriptionHTTPClassifier.classifyHTTPError(
            statusCode: 403,
            headers: ["x-subscription-expired": "true"],
            body: ""
        )
        XCTAssertEqual(c.category, .subscriptionExpired)
    }

    func testSuccessBodyXrayJSON() throws {
        let url = fixtureURL("panels/remnawave/xray_json_locations.json")
        let body = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(
            VPNDirectSubscriptionHTTPClassifier.classifySuccessBody(body),
            .xrayJSON
        )
    }

    func testSuccessBodyBrowser() {
        let body = "<!DOCTYPE html><html><body>login</body></html>"
        XCTAssertEqual(
            VPNDirectSubscriptionHTTPClassifier.classifySuccessBody(body),
            .browser
        )
    }

    func testFlat3xUISettingsVLESS() throws {
        let url = fixtureURL("panels/3x-ui/xray_flat_settings.json")
        let body = try String(contentsOf: url, encoding: .utf8)
        let sub = try XrayJSONAdapter.parse(body)
        XCTAssertEqual(sub.locations.count, 1)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.protocolID, .vless)
        XCTAssertEqual(node.server, "203.0.113.41")
        XCTAssertEqual(node.port, 8443)
        XCTAssertEqual(node.attributes["uuid"], "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(node.attributes["flow"], "xtls-rprx-vision")
    }

    func test3xUIMuxAndFinalMaskMapped() throws {
        let url = fixtureURL("panels/3x-ui/xray_mux_finalmask.json")
        let body = try String(contentsOf: url, encoding: .utf8)
        let sub = try XrayJSONAdapter.parse(body)
        let node = try XCTUnwrap(sub.locations.first?.endpoints.first)
        XCTAssertEqual(node.protocolID, .vless)
        XCTAssertEqual(node.attributes["multiplex"], "1")
        XCTAssertTrue(node.attributes["multiplex_json"]?.contains("\"enabled\"") == true)
        XCTAssertEqual(node.attributes["tls_fragment"], "1")
        let built = try UniversalOutboundBuilder.build(from: node)
        let multiplex = try XCTUnwrap(built["multiplex"] as? [String: Any])
        XCTAssertEqual(multiplex["enabled"] as? Bool, true)
        XCTAssertEqual(multiplex["max_connections"] as? Int, 8)
        let tls = try XCTUnwrap(built["tls"] as? [String: Any])
        XCTAssertEqual(tls["fragment"] as? Bool, true)
    }

    func test3xUIFinalMaskUDPFailsClosed() throws {
        let body = """
        [{"tag":"bad","protocol":"vless","settings":{"address":"x.test","port":443,"id":"33333333-3333-3333-3333-333333333333"},"streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"serverName":"x.test"},"finalmask":{"udp":[{"type":"noise","settings":{"packet":"AA=="}}]}},"mux":{"enabled":false}}]
        """
        XCTAssertThrowsError(try XrayJSONAdapter.parse(body))
    }

    private func fixtureURL(_ relative: String) -> URL {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("../fixtures/\(relative)"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("fixtures/\(relative)"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("../../fixtures/\(relative)"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("../../../fixtures/\(relative)"),
        ]
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        // Resolve from package root via known layout.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // VPNDirectParserPackage
            .appendingPathComponent("fixtures/\(relative)")
        return root
    }
}
