# SPEC 0xx — MASQUE CONNECT-UDP outbound (RFC 9298)

Status: IMPLEMENTED (minimal) — 2026-09-08

## Goal

Ship a UDP-proxy outbound distinct from CONNECT-IP (`type: masque` / WARP):

- Config type: `masque-connect-udp`
- Wire: HTTP/3 Extended CONNECT with `:protocol = connect-udp`
- Capability: `masqueConnectUDP` / `VPNDirectSupportsMASQUEConnectUDP()` → true when `with_quic`

## Non-goals

- Not a full L3 IP tunnel (use CONNECT-IP / WARP for that)
- No H2 CONNECT-UDP path in v1 (datagrams require H3)
- No capsule-based multi-context multiplexing beyond one stream per destination

## Schema

```json
{
  "type": "masque-connect-udp",
  "tag": "mcu",
  "server": "proxy.example.com",
  "server_port": 443,
  "uri": "https://proxy.example.com/.well-known/masque/udp/{target_host}/{target_port}/",
  "vhttp": "h3",
  "tls": { "enabled": true, "server_name": "proxy.example.com" }
}
```

## Files

- `option/masque_connect_udp.go`
- `protocol/masque_connect_udp/outbound.go`
- `transport/masque/connect_udp.go` + `connect_udp_conn.go`
- `include/quic.go` registration
- Swift: `MasqueConnectUDPAdapter` + detector kind `masqueConnectUDPJSON`
