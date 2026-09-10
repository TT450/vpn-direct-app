# ShadowTLS → SS chain

1. Run SS on 127.0.0.1:8388 with fixture password.
2. Front with ShadowTLS listening on 0.0.0.0:443, handshake SNI `www.example.com`.
3. Client uses `shadowtls://` or Clash `plugin: shadow-tls`.

Server host example: `203.0.113.50` (DOCUMENTATION).
