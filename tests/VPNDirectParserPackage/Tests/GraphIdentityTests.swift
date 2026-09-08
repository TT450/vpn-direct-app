import Foundation
import XCTest
@testable import VPNDirectParsers

/// Graph identity policy: TheTochka/Happ tags from display names + ChatGPT no name-collapse.
final class GraphIdentityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testSameDisplayNameDifferentHostsStayDistinctWithUniquifiedTags() throws {
        let yaml = """
        proxies:
          - name: Germany
            type: socks5
            server: 203.0.113.10
            port: 1080
          - name: Germany
            type: socks5
            server: 203.0.113.11
            port: 1080
        """
        let sub = try ClashYAMLAdapter.parse(yaml)
        let graph = try SingBoxGraphBuilder.build(from: sub)
        let root = try XCTUnwrap(graph.json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: root) as? [String: Any])
        let outbounds = try XCTUnwrap(obj["outbounds"] as? [[String: Any]])
        let socks = outbounds.filter { ($0["type"] as? String) == "socks" }
        XCTAssertEqual(socks.count, 2, "must not collapse leaves by display name")
        let tags = Set(socks.compactMap { $0["tag"] as? String })
        XCTAssertEqual(tags.count, 2)
        XCTAssertTrue(tags.contains("Germany"))
        XCTAssertTrue(tags.contains("Germany-2"))
    }

    func testAmbiguousDetourByDisplayNameFailsClosed() throws {
        let a = NormalizedNode(
            name: "Relay",
            protocolID: .socks,
            server: "203.0.113.10",
            port: 1080,
            attributes: [:],
            outbound: [
                "type": "socks",
                "server": "203.0.113.10",
                "server_port": 1080,
            ]
        )
        let b = NormalizedNode(
            name: "Relay",
            protocolID: .socks,
            server: "203.0.113.11",
            port: 1080,
            attributes: [:],
            outbound: [
                "type": "socks",
                "server": "203.0.113.11",
                "server_port": 1080,
            ]
        )
        var hop = NormalizedNode(
            name: "Edge",
            protocolID: .socks,
            server: "198.51.100.1",
            port: 1080,
            attributes: [:],
            outbound: [
                "type": "socks",
                "server": "198.51.100.1",
                "server_port": 1080,
            ]
        )
        hop.detour = "Relay"
        let sub = NormalizedSubscription(
            name: "ambig",
            locations: [
                NormalizedLocation(id: "loc-1", name: "All", kind: .group, strategy: .select, endpoints: [a, b, hop]),
            ]
        )
        XCTAssertThrowsError(try SingBoxGraphBuilder.build(from: sub)) { error in
            let text = String(describing: error)
            XCTAssertTrue(text.contains("ambiguous") || text.contains("Relay"), "got \(text)")
        }
    }
}
