# Protocol matrix — VPN Direct Core 0.1

Last docs sync: **2026-09-07** (app release **v1.0.8**). Status legend: `planned` | `parser` | `runtime` | `parser+runtime` | `qualification_ready` | `tested` | `deferred` | `out_of_scope`

## Support definition (`tested`)

A protocol/transport row may move to **`tested`** only when all of the following are proven on a real device build of this Core pin:

1. Parser / builder emits valid config (or import rejects with `unsupportedFeature` — never silent downgrade)
2. Linked Libbox CapabilityJSON / tags prove the feature (fail-closed)
3. `LibboxCheckConfig` accepts the runtime JSON (no `_vpndirect_*` unknown keys)
4. Packet Tunnel starts
5. Interop server accepts the session (TCP and UDP as applicable)
6. DNS through the tunnel works
7. Reconnect / profile switch works
8. Network Extension RSS stays within the project budget vs stock Libbox

Until then, keep `runtime` / `parser+runtime` / `qualification_ready` / `planned` even if builders exist.

**Interop=`planned` is intentional** until battle-key evidence files are committed. Product is **qualification-ready** when detectors, parsers, builders, and Core registration are green (`scripts/check_production_ready.sh`).

Panel / format compatibility (URI × Xray × Clash × fixtures) lives in [`docs/compatibility/`](../compatibility/README.md) and [`core/panel-compatibility.json`](../../core/panel-compatibility.json). A panel is not “supported” from a single sample link.

## Capability policy

- No silent XHTTP → HTTPUpgrade (or any other) downgrade.
- Capability Registry is **fail-closed**: unproven ⇒ `false` / empty lists.
- AWG versions and Hysteria2 `gecko` come from Core CapabilityJSON, not Swift hardcodes.
- Mieru capability is `true` only in Libbox builds tagged `with_mieru` (registered outbound).
- Parser=`yes` requires a fixture + builder path in-tree.
- Clash nested `ws-opts` / `grpc-opts` / `reality-opts` / `plugin-opts` flatten to attributes (**Yams** when linked; hardened subset fallback).

## Matrix

| Protocol | Version | Transport | Security | Obfuscation | Parser | Core | iOS | Interop | Status | Source |
|----------|---------|-----------|----------|-------------|--------|------|-----|---------|--------|--------|
| VLESS | current | tcp/ws/grpc/httpupgrade | tls/reality | — | yes | yes | yes | planned | parser+runtime | sing-box |
| VLESS | current | xhttp | tls/reality | — | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| VLESS | encryption | * | * | PQ mlkem… | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| VMess | current | * | * | — | yes | yes | yes | planned | parser+runtime | sing-box |
| Trojan | current | * | * | — | yes | yes | yes | planned | parser+runtime | sing-box |
| Shadowsocks / 2022 | current | — | — | — | yes | yes | yes | planned | parser+runtime | sing-box |
| Hysteria / Hysteria2 | current | quic | tls | salamander/gecko* | yes | yes* | yes | planned | parser+runtime | sing-box / TheTochka harvest |
| TUIC | v5 | quic | tls | — | yes | yes | yes | planned | parser+runtime | sing-box |
| AnyTLS | current | — | — | — | yes | yes | yes | planned | parser+runtime | sing-box |
| ShadowTLS | current | — | — | — | yes | yes | yes | planned | parser+runtime | sing-box |
| NaiveProxy | current | — | — | — | yes | yes | yes | planned | parser+runtime | sing-box |
| WireGuard | current | udp | — | — | yes | yes | yes | planned | parser+runtime | sing-box |
| AmneziaWG | 2 / 3.0 / 3.1 | udp | — | AWG fields | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| MASQUE | CONNECT-IP | h3/h2 | tls | — | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| MASQUE | CONNECT-UDP | — | — | — | — | no | — | — | out_of_scope | — |
| WARP | via MASQUE | h3/h2 | pin | — | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| Mieru | TCP/UDP/LE | — | — | low entropy | yes | yes (`with_mieru`) | yes | planned | parser+runtime | mbox |
| SSH/SOCKS/HTTP | current | — | — | — | yes | yes | yes | planned | parser+runtime | sing-box |
| Tailscale | — | — | — | — | — | no (ios profile) | — | — | out_of_scope | — |
| OpenVPN / OpenConnect | — | — | — | — | — | no (ios profile) | — | — | out_of_scope | — |

\* Update rows when `core/VERSION` and real device tests change.

### Outbound debt note

`NormalizedNode.outbound` early-return in `UniversalOutboundBuilder` is marked `// LEGACY` for older writers. Clash, Mieru, share-link parsers, and **Xray JSON** (`XrayJSONAdapter`) prefer attributes-only; converters still produce outbound dicts only as an intermediate flatten source.

Machine-readable: [`core/protocol-matrix.json`](../../core/protocol-matrix.json).

See also: [`MIERU_DEFERRED.md`](MIERU_DEFERRED.md), [`PANIC_BOUNDARY.md`](PANIC_BOUNDARY.md), [`REMOTES.md`](REMOTES.md), [`BUILDING.md`](BUILDING.md), [`docs/device/IPHONE_QUALIFICATION.md`](../device/IPHONE_QUALIFICATION.md).
