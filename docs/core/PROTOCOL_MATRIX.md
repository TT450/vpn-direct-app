# Protocol matrix — VPN Direct Core 0.1

Status legend: `planned` | `parser` | `runtime` | `tested` | `deferred`

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

Until then, keep `runtime` / `parser+runtime` / `planned` even if builders exist.

## Capability policy

- No silent XHTTP → HTTPUpgrade (or any other) downgrade.
- Capability Registry is **fail-closed**: unproven ⇒ `false` / empty lists.
- AWG versions and Hysteria2 `gecko` come from Core CapabilityJSON, not Swift hardcodes.
- Mieru remains deferred until merged into `core/sing-box`.

## Matrix

| Protocol | Version | Transport | Security | Obfuscation | Parser | Core | iOS | Interop | Status | Source |
|----------|---------|-----------|----------|-------------|--------|------|-----|---------|--------|--------|
| VLESS | current | tcp/ws/grpc/httpupgrade | tls/reality | — | yes | yes | yes | partial | runtime | sing-box |
| VLESS | current | xhttp | tls/reality | — | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| VLESS | encryption | * | * | PQ mlkem… | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| VMess | current | * | * | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| Trojan | current | * | * | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| Shadowsocks / 2022 | current | — | — | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| Hysteria / Hysteria2 | current | quic | tls | salamander/gecko* | planned | yes* | yes | planned | runtime(JSON) | sing-box (*gecko via CapabilityJSON) |
| TUIC | v5 | quic | tls | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| AnyTLS | current | — | — | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| ShadowTLS | current | — | — | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| NaiveProxy | current | — | — | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| WireGuard | current | udp | — | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| AmneziaWG | 2 / 3.0 / 3.1 | udp | — | AWG fields | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| MASQUE | CONNECT-IP | h3/h2 | tls | — | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| MASQUE | CONNECT-UDP | — | — | — | — | no | — | — | deferred | — |
| WARP | via MASQUE | h3/h2 | pin | — | yes | yes | yes | planned | parser+runtime | sing-box-lx |
| Mieru | TCP/UDP/LE | — | — | low entropy | — | tag | trial | planned | deferred (see MIERU_DEFERRED.md) | mbox |
| SSH/SOCKS/HTTP | current | — | — | — | planned | yes | yes | — | runtime(JSON) | sing-box |
| Tailscale | — | — | — | — | — | no (ios profile) | — | — | deferred | — |
| OpenVPN / OpenConnect | — | — | — | — | — | no (ios profile) | — | — | deferred | — |

\* Update rows when `core/VERSION` and real device tests change.

See also: [`MIERU_DEFERRED.md`](MIERU_DEFERRED.md), [`REMOTES.md`](REMOTES.md), [`BUILDING.md`](BUILDING.md).
