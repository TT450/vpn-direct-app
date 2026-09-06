# What's New — VPN Direct 1.0.5

Release date: 2026-09-07  
Git tag: `v1.0.5`

## App Store / short What's New

- Broader subscription import: VMess, Trojan, Shadowsocks, TUIC, AnyTLS, WireGuard/AWG, SOCKS, HTTP proxy, SSH
- Clash / Mihomo YAML proxies and smarter content detection (JSON / YAML / conf / URI)
- Remnawave/Happ topology from 1.0.4 kept; docs and Protocol Matrix refreshed
- Production readiness gate: `make check-production-ready`

## Engineering detail

- `VPNDirectContentDetector` — ordered detect, no YAML line-trim
- Universal share-link parsers + `UniversalOutboundBuilder`
- Clash YAML adapter (proxies only); Xray leaves: VLESS / HY / VMess / Trojan / SS
- `VPNDirectConfigValidator`, error model v2, `VPNDirectRedactor`
- `core/protocol-matrix.json`, interop scaffolds, iPhone qualification checklist
- Mieru: Swift parse + fail-closed emit; Core runtime still off (`with_mieru` not in tags)

### Still not `tested` / production

Interop lab evidence and filled device qualification are required before matrix rows move to `tested`. CONNECT-UDP / Tailscale / OpenVPN remain `out_of_scope`.

See also: `docs/core/PROTOCOL_MATRIX.md`, `ROADMAP.md`, `CHANGELOG.md`.
