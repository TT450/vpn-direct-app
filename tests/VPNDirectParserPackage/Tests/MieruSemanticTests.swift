import Foundation
@testable import VPNDirectParsers
import XCTest

final class MieruSemanticTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testMissingTransportFailsClosed() {
        let json = #"{"server":"vpn.example.com","port":443,"username":"u","password":"p"}"#
        XCTAssertThrowsError(try MieruConfigAdapter.parse(json))
    }

    func testLowEntropyIsNotStringifiedIntoTrafficPattern() {
        let json = #"{"server":"vpn.example.com","port":443,"transport":"TCP","username":"u","password":"p","lowEntropy":true}"#
        XCTAssertThrowsError(try MieruConfigAdapter.parse(json))
    }

    func testExplicitTCPProfileParsesWithoutInventedFields() throws {
        let json = #"{"server":"vpn.example.com","port":443,"transport":"TCP","username":"u","password":"p"}"#
        let subscription = try MieruConfigAdapter.parse(json)
        let node = try XCTUnwrap(subscription.locations.first?.endpoints.first)
        XCTAssertEqual(node.transport?.rawValue, "tcp")
        XCTAssertEqual(node.attributes["transport"], "TCP")
        XCTAssertNil(node.attributes["traffic_pattern"])
    }
}
