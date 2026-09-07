import Foundation
import XCTest
@testable import VPNDirectParsers

final class ClashProxyGroupsTests: XCTestCase {
    func testLiberteaNestedProxyGroupsPreserveTopology() throws {
        let url = fixturesURL().appendingPathComponent("panels/libertea/groups_clash.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let sub = try ClashYAMLAdapter.parse(text)

        XCTAssertEqual(sub.locations.count, 3)
        let byName = Dictionary(uniqueKeysWithValues: sub.locations.map { ($0.name, $0) })

        let groupA = try XCTUnwrap(byName["GROUP-A"])
        XCTAssertEqual(groupA.strategy, .select)
        XCTAssertEqual(groupA.kind, .group)
        XCTAssertEqual(groupA.endpoints.map(\.name), ["Libertea-Primary", "Libertea-Secondary"])
        XCTAssertTrue(groupA.memberLocationIDs.isEmpty)

        let groupB = try XCTUnwrap(byName["GROUP-B"])
        XCTAssertEqual(groupB.strategy, .fallback)
        XCTAssertEqual(groupB.kind, .fallback)
        XCTAssertEqual(groupB.endpoints.map(\.name), ["Libertea-Secondary", "Libertea-Relay", "Libertea-Primary"])
        XCTAssertEqual(groupB.healthCheckURL, "http://www.gstatic.com/generate_204")
        XCTAssertEqual(groupB.healthCheckInterval, "300s")

        let auto = try XCTUnwrap(byName["AUTO-FAILOVER"])
        XCTAssertEqual(auto.strategy, .fallback)
        XCTAssertTrue(auto.endpoints.isEmpty)
        XCTAssertEqual(auto.memberLocationIDs, ["GROUP-A", "GROUP-B"])
        XCTAssertEqual(auto.healthCheckInterval, "60s")

        // Nested group refs must not be flattened into leaf endpoints on AUTO.
        XCTAssertFalse(auto.endpoints.contains(where: { $0.name.hasPrefix("Libertea-") }))
    }

    func testFlatClashWithoutGroupsStillImports() throws {
        let yaml = """
        proxies:
          - name: Alone
            type: socks5
            server: 203.0.113.10
            port: 1080
        """
        let sub = try ClashYAMLAdapter.parse(yaml)
        XCTAssertEqual(sub.locations.count, 1)
        XCTAssertEqual(sub.locations[0].endpoints.count, 1)
        XCTAssertEqual(sub.locations[0].strategy, .single)
    }

    func testProxyProviderUseIsExplicitUnsupportedWhenOnlyGroup() throws {
        let yaml = """
        proxies:
          - name: Leaf
            type: socks5
            server: 203.0.113.10
            port: 1080
        proxy-groups:
          - name: FROM-PROVIDER
            type: select
            use:
              - my-provider
        """
        XCTAssertThrowsError(try ClashYAMLAdapter.parse(yaml)) { error in
            let text = String(describing: error)
            XCTAssertTrue(
                text.contains("proxy-providers") || text.contains("use:") || text.contains("FROM-PROVIDER"),
                "expected explicit provider unsupported diagnostic, got \(text)"
            )
        }
    }

    private func fixturesURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
    }
}
