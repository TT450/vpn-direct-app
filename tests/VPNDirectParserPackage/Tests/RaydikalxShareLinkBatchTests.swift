import Foundation
import XCTest
@testable import VPNDirectParsers

final class RaydikalxShareLinkBatchTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ParserTestSupport.installCapabilities()
    }

    func testMixedPasteDoesNotDieOnSSRAndHTMLBreak() throws {
        let paste = """
        vmess://eyJ2IjogIjIiLCAicHMiOiAidGVsZWdyYW0gXHVkODNjXHVkZjFmIGRhaWx5djJyeSIsICJhZGQiOiAiODIuMTk4LjI0Ni45NyIsICJwb3J0IjogIjE4MCIsICJpZCI6ICJkMTNmYzJmNS0zZTA1LTQ3OTUtODFlYi00NDE0M2EwOWU1NTIiLCAiYWlkIjogIjAiLCAic2N5IjogImF1dG8iLCAibmV0IjogInRjcCIsICJ0eXBlIjogIm5vbmUiLCAiaG9zdCI6ICIiLCAicGF0aCI6ICIiLCAidGxzIjogIiIsICJzbmkiOiAiIiwgImFscG4iOiAiIiwgImZwIjogIiJ9<br/>ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpBUmd2R1p5d0ErZ2FjZ0dWMjZCdm11MDUrd1ptUlcvaitBZFUrWjhCdDQ0PQ@45.82.252.109:990#HK
        ssr://bGl2ZS5iaWxpYmlsaWNsb3VkMDEuY29tOjU0MTEyOmF1dGhfYWVzMTI4X3NoYTE6Y2hhY2hhMjAtaWV0ZjpwbGFpbjpUWFkwWlRCUlNGZFFkMlJpUzJsRFJnPT0vP29iZnNwYXJhbT0mcmVtYXJrcz04SiUyQkhyZkNmaDdCSVN5MHhPQzR4TmpZdU1UVTBMakk0TFRBeU16YyUzRCZwcm90b3BhcmFtPQ==#JP
        hy2://1671a252e2a97dc2bda4e515475931da@132.226.226.189:50160/?insecure=1&sni=www.bing.com#KR
        """
        let detection = VPNDirectContentDetector.detect(text: paste)
        XCTAssertEqual(detection.kind, .uriList)

        let links = detection.text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let result = VPNDirectParserRegistry.parseShareLinks(links)
        XCTAssertGreaterThanOrEqual(result.diagnostics.parsed, 4)
        XCTAssertEqual(result.diagnostics.unsupported, 0)
        XCTAssertFalse(result.diagnostics.unsupportedComponents.contains("ssr"))
        XCTAssertTrue(result.nodes.contains(where: { $0.protocolID == .vmess }))
        XCTAssertTrue(result.nodes.contains(where: { $0.protocolID == .shadowsocks }))
        XCTAssertTrue(result.nodes.contains(where: { $0.protocolID == .shadowsocksr }))
        XCTAssertTrue(result.nodes.contains(where: { $0.protocolID == .hysteria2 }))
        let ssr = try XCTUnwrap(result.nodes.first(where: { $0.protocolID == .shadowsocksr }))
        let ssrOut = try UniversalOutboundBuilder.build(from: ssr)
        XCTAssertEqual(ssrOut["type"] as? String, "shadowsocksr")
    }

    func testSSLabeledVLESSURIRewrites() throws {
        let link =
            "ss://30f2d443-af46-4dd6-83c9-b5e17299ebd2@104.18.36.24:443?encryption=none&security=tls&sni=carlotta.shoorekeeper.cloudns.org&fp=chrome&type=ws&host=carlotta.shoorekeeper.cloudns.org&path=/proxyip=zani.yaemiko.ggff.net/?JOKERRVPN_BIA_CHANEL@JOKERRVPN#CA"
        let node = try ShadowsocksShareLinkParser().parseShareLink(link)
        XCTAssertEqual(node.protocolID, .vless)
        let outbound = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(outbound["type"] as? String, "vless")
    }

    func testHY2FMSalamanderAndTUICAllowInsecure() throws {
        let hy =
            #"hysteria2://4savc5ig1n3549e4@giftcard.gateway-stream.com:52023?security=tls&fm={"udp":[{"settings":{"password":"fuw2k1ddrouwxr3u"},"type":"salamander"}]}&sni=giftcard.gateway-stream.com&allowinsecure=0#FI"#
        let hyNode = try HysteriaShareLinkParser().parseShareLink(hy)
        XCTAssertEqual(hyNode.attributes["obfs"], "salamander")
        let hyOut = try UniversalOutboundBuilder.build(from: hyNode)
        let obfs = try XCTUnwrap(hyOut["obfs"] as? [String: Any])
        XCTAssertEqual(obfs["type"] as? String, "salamander")
        XCTAssertEqual(obfs["password"] as? String, "fuw2k1ddrouwxr3u")

        let tuic =
            "tuic://56d8a8fd-68b8-47f8-8c7f-98cc675902db:56d8a8fd-68b8-47f8-8c7f-98cc675902db@us02.uzifan.monster:8443/?congestion_control=bbr&udp_relay_mode=native&sni=www.bing.com&alpn=h3&allow_insecure=1#US"
        let tuicNode = try TUICShareLinkParser().parseShareLink(tuic)
        let tuicOut = try UniversalOutboundBuilder.build(from: tuicNode)
        let tls = try XCTUnwrap(tuicOut["tls"] as? [String: Any])
        XCTAssertEqual(tls["insecure"] as? Bool, true)
    }
}
