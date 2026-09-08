# MASQUE

## CONNECT-IP (RFC 9484)

Product outbound `type: "masque"` — Cloudflare WARP / standard CONNECT-IP profiles (`h3` / `h2` / `auto`). Capability: `masqueConnectIP`.

## CONNECT-UDP (RFC 9298)

Product outbound `type: "masque-connect-udp"` — UDP proxy over HTTP/3 Extended CONNECT (not an L3 IP tunnel).

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

Import: paste / Import from File JSON → `MasqueConnectUDPAdapter` (gated on `supportsMASQUEConnectUDP`).

Do **not** confuse with AmneziaWG “masquerade” junk fields (`id`/`ip`/`ib`) — unrelated.
