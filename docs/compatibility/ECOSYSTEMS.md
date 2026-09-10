# Ecosystems

```text
A. Xray ecosystem     — Xray-core + 3x-ui / x-ui / tx-ui / Remnawave / Marzban / Marzneshin / PasarGuard / Hiddify / Libertea
B. sing-box ecosystem — SagerNet/sing-box + sing-box-lx + s-ui + native JSON
C. WireGuard / AmneziaWG — wg-easy, Amnezia, amneziawg-go
D. MASQUE / WARP      — RFC 9484 CONNECT-IP vs Cloudflare WARP profile
E. Mieru              — mita server + mieru client + mbox sing-box donor
F. Standalone         — Hysteria, TUIC, AnyTLS, ShadowTLS(+SS), NaiveProxy, SOCKS/HTTP/SSH
G. Tier-2             — Tailscale/Headscale, OpenVPN, OpenConnect, IKEv2 (product out_of_scope for Core 1.x claims)
```

VPN Direct Core sits on **B** (sing-box-lx). Client import must understand **A–F** subscription contracts without requiring Admin APIs on device.

```text
Provider / Panel
  → Subscription transport (HTTP)
  → Response metadata + format body
  → Format adapter
  → NormalizedSubscription / Location / Node (+ rawExtensions)
  → Capability resolver
  → UniversalOutboundBuilder
  → LibboxCheckConfig / Packet Tunnel
```
