import XCTest
@testable import VPNDirectParsers

final class AdvancedProtocolFieldTests: XCTestCase {
    func testHY2PreservesServerPortsAndHopInterval() throws {
        let node = NormalizedNode(
            name: "hy2-hop",
            protocolID: .hysteria2,
            server: "hy2.example.com",
            port: 443,
            uuid: "secret-password",
            attributes: [
                "password": "secret-password",
                "sni": "hy2.example.com",
                "server_ports": "20000:30000,40000",
                "hop_interval": "30s",
                "hop_interval_max": "60s",
                "obfs": "salamander",
                "obfs_password": "obfs-secret",
                "up_mbps": "50",
                "down_mbps": "100",
            ]
        )
        let out = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(out["type"] as? String, "hysteria2")
        XCTAssertEqual(out["server_ports"] as? [String], ["20000:30000", "40000"])
        XCTAssertEqual(out["hop_interval"] as? String, "30s")
        XCTAssertEqual(out["hop_interval_max"] as? String, "60s")
        XCTAssertEqual(out["up_mbps"] as? Int, 50)
        XCTAssertEqual(out["down_mbps"] as? Int, 100)
        let obfs = out["obfs"] as? [String: Any]
        XCTAssertEqual(obfs?["type"] as? String, "salamander")
        XCTAssertEqual(obfs?["password"] as? String, "obfs-secret")
    }

    func testHY2DoesNotInventBandwidthDefaults() throws {
        let node = NormalizedNode(
            name: "hy2-no-bw",
            protocolID: .hysteria2,
            server: "hy2.example.com",
            port: 443,
            uuid: "pw",
            attributes: ["password": "pw", "sni": "hy2.example.com"]
        )
        let out = try UniversalOutboundBuilder.build(from: node)
        XCTAssertNil(out["up_mbps"])
        XCTAssertNil(out["down_mbps"])
    }

    func testTUICEmitsAdvancedNonDefaultFields() throws {
        let node = NormalizedNode(
            name: "tuic-adv",
            protocolID: .tuic,
            server: "tuic.example.com",
            port: 443,
            uuid: "11111111-1111-1111-1111-111111111111",
            attributes: [
                "password": "tuic-pass",
                "congestion_control": "bbr",
                "udp_relay_mode": "quic",
                "udp_over_stream": "true",
                "zero_rtt_handshake": "1",
                "heartbeat": "10s",
                "network": "udp",
                "sni": "tuic.example.com",
                "alpn": "h3",
            ]
        )
        let out = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(out["congestion_control"] as? String, "bbr")
        XCTAssertEqual(out["udp_relay_mode"] as? String, "quic")
        XCTAssertEqual(out["udp_over_stream"] as? Bool, true)
        XCTAssertEqual(out["zero_rtt_handshake"] as? Bool, true)
        XCTAssertEqual(out["heartbeat"] as? String, "10s")
        XCTAssertEqual(out["network"] as? String, "udp")
        let tls = out["tls"] as? [String: Any]
        XCTAssertEqual(tls?["alpn"] as? [String], ["h3"])
    }

    func testNaiveEmitsTLSAndQUICAdvancedFields() throws {
        let node = NormalizedNode(
            name: "naive-adv",
            protocolID: .naive,
            server: "naive.example.com",
            port: 443,
            attributes: [
                "username": "u",
                "password": "p",
                "quic": "1",
                "quic_congestion_control": "bbr",
                "insecure_concurrency": "4",
                "stream_receive_window": "6MB",
                "sni": "naive.example.com",
            ]
        )
        let out = try UniversalOutboundBuilder.build(from: node)
        XCTAssertEqual(out["quic"] as? Bool, true)
        XCTAssertEqual(out["quic_congestion_control"] as? String, "bbr")
        XCTAssertEqual(out["insecure_concurrency"] as? Int, 4)
        XCTAssertEqual(out["stream_receive_window"] as? String, "6MB")
        let tls = out["tls"] as? [String: Any]
        XCTAssertEqual(tls?["enabled"] as? Bool, true)
        XCTAssertEqual(tls?["server_name"] as? String, "naive.example.com")
    }

    func testSSHMissingUserFailsClosed() {
        let node = NormalizedNode(
            name: "ssh-bad",
            protocolID: .ssh,
            server: "ssh.example.com",
            port: 22,
            attributes: ["password": "x"]
        )
        XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node))
    }

    func testMASQUERequiresExplicitProfile() {
        let node = NormalizedNode(
            name: "masque-bad",
            protocolID: .masque,
            server: "masque.example.com",
            port: 443,
            attributes: [
                "private_key": "pk",
                "peer_public_key": "ppk",
                "local_address": "172.16.0.2/32",
            ]
        )
        XCTAssertThrowsError(try UniversalOutboundBuilder.build(from: node))
    }
}
