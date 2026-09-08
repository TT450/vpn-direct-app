import XCTest
@testable import VPNDirectParsers

final class TunnelEndpointImportTests: XCTestCase {
    func testOpenVPNConfDetectAndBuild() throws {
        let ovpn = """
        client
        dev tun
        proto udp
        remote vpn.example.com 1194
        <ca>
        -----BEGIN CERTIFICATE-----
        MIIB
        -----END CERTIFICATE-----
        </ca>
        <cert>
        -----BEGIN CERTIFICATE-----
        MIIB
        -----END CERTIFICATE-----
        </cert>
        <key>
        -----BEGIN PRIVATE KEY-----
        MIIE
        -----END PRIVATE KEY-----
        </key>
        """
        let detection = VPNDirectContentDetector.detect(text: ovpn)
        XCTAssertEqual(detection.kind, .openVPNConfig)
        let sub = try OpenVPNConfigAdapter.parse(ovpn)
        let graph = try SingBoxGraphBuilder.build(from: sub)
        XCTAssertTrue(graph.json.contains("openvpn-client"))
        XCTAssertTrue(graph.json.contains("vpn.example.com"))
    }

    func testTailscaleJSONDetectAndBuild() throws {
        let json = """
        {
          "type": "tailscale",
          "tag": "ts",
          "auth_key": "tskey-auth-test",
          "control_url": "https://controlplane.tailscale.com",
          "hostname": "iphone"
        }
        """
        let detection = VPNDirectContentDetector.detect(text: json)
        XCTAssertEqual(detection.kind, .tailscaleJSON)
        let sub = try TailscaleConfigAdapter.parse(json)
        let graph = try SingBoxGraphBuilder.build(from: sub)
        XCTAssertTrue(graph.json.contains("tailscale"), graph.json)
    }

    func testOpenConnectJSONDetectAndBuild() throws {
        let json = """
        {
          "type": "openconnect",
          "tag": "oc",
          "server": "https://vpn.example.com",
          "flavor": "anyconnect",
          "username": "user",
          "password": "pass"
        }
        """
        let detection = VPNDirectContentDetector.detect(text: json)
        XCTAssertEqual(detection.kind, .openConnectConfig)
        let sub = try OpenConnectConfigAdapter.parse(json)
        let graph = try SingBoxGraphBuilder.build(from: sub)
        XCTAssertTrue(graph.json.contains("openconnect"))
    }

    func testMasqueConnectUDPJSONDetectAndBuild() throws {
        let json = """
        {
          "type": "masque-connect-udp",
          "tag": "mcu",
          "server": "proxy.example.com",
          "server_port": 443,
          "uri": "https://proxy.example.com/.well-known/masque/udp/{target_host}/{target_port}/",
          "tls": { "enabled": true, "server_name": "proxy.example.com" }
        }
        """
        let detection = VPNDirectContentDetector.detect(text: json)
        XCTAssertEqual(detection.kind, .masqueConnectUDPJSON)
        let sub = try MasqueConnectUDPAdapter.parse(json)
        let graph = try SingBoxGraphBuilder.build(from: sub)
        XCTAssertTrue(graph.json.contains("masque-connect-udp"))
    }
}
