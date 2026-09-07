# Battle Source Plan

Date: **2026-09-07**  
Companion: [`BATTLE_COVERAGE.md`](BATTLE_COVERAGE.md), [`EXTERNAL_CREDENTIALS.md`](EXTERNAL_CREDENTIALS.md), [`tests/battle/public-sources.json`](../../tests/battle/public-sources.json).

## Goal

For every in-scope PROTOCOL_MATRIX variant, VPN Direct has **(A)** intentional public/free/test sources and/or **(B)** a reproducible self-hosted reference lab under `interop/protocols/`.

Pipeline:

```text
public/test source or own lab
→ fetch/import
→ VPNDirectContentDetector + adapters
→ NormalizedSubscription
→ UniversalOutboundBuilder
→ sing-box / Libbox check
→ optional live connect (TCP/UDP/DNS)
→ structured evidence (no secrets)
```

## Volatility policy

Public sources are **volatile**. Status classes:

| Class | Meaning | CI impact |
| --- | --- | --- |
| `SOURCE_FETCH_FAILED` | HTTP/network failure | warn only |
| `SOURCE_EMPTY` | 200 but no usable body | warn only |
| `PARSE_FAILED` / `malformed_input` | body present, parser reject | report; golden fixtures may fail CI |
| `CONFIG_INVALID` | builder/core reject | report |
| `CONNECT_FAILED` / `remote_server_dead` | live handshake | never required CI |
| `SUCCESS` | stage passed | evidence |

A vanished public node is **not** a parser regression.

## Variant audit

Legend for strategy columns: `public` = intentional free pools; `lab` = `interop/protocols/<family>`; `oos` = out of scope.

| Variant ID | Strategy | Public catalog | Reference lab | Notes |
| --- | --- | --- | --- | --- |
| vless-tcp | public+lab | morpheus / 0xRadikal / Epodonios | protocols/xray | |
| vless-tls | public+lab | same | protocols/xray | |
| vless-reality | public+lab | reality bundles | protocols/xray | |
| vless-vision | public+lab | flow=xtls-rprx-vision | protocols/xray | |
| vless-ws | public+lab | type=ws | protocols/xray | |
| vless-grpc | public+lab | type=grpc | protocols/xray | |
| vless-httpupgrade | public+lab | rare in pools | protocols/xray | lab-first if pool empty |
| vless-xhttp | lab-first | rare | protocols/xray | capability-gated |
| vless-xhttp-reality | lab-first | rare | protocols/xray | |
| vless-encryption-pq | lab-first | rare | protocols/xray | mlkem string |
| vmess | public+lab | pools | protocols/xray | |
| trojan | public+lab | pools | protocols/xray | |
| shadowsocks | public+lab | pools | protocols/xray | |
| shadowsocks-2022 | public+lab | method 2022-* | protocols/xray | |
| hysteria | public+lab | rare | protocols/hysteria | hy1 |
| hysteria2 | public+lab | hy2 pools | protocols/hysteria | |
| hy2-salamander | lab-first | obfs | protocols/hysteria | |
| hy2-gecko | lab-first | capability | protocols/hysteria | |
| tuic-v5 | public+lab | tuic pools | protocols/tuic | |
| anytls | public+lab | 0xRadikal anytls | protocols/anytls | |
| shadowtls | lab-first | rare | protocols/shadowtls | chain → SS |
| naive | lab-first | rare | protocols/naive | |
| wireguard | public+lab | WG bundles + WARP conf | protocols/wireguard | |
| amneziawg-2 | lab | — | protocols/amneziawg | controlled fields |
| amneziawg-3.0 | lab | — | protocols/amneziawg | |
| amneziawg-3.1 | lab | — | protocols/amneziawg | |
| masque-connect-ip | lab | — | protocols/masque | |
| warp-masque | public parser + external live | Delta-Kronecker WARP-Config | protocols/masque | identity via env |
| mieru-tcp | lab | — | protocols/mieru | |
| mieru-udp | lab | — | protocols/mieru | |
| mieru-le-32 | lab | — | protocols/mieru | |
| mieru-le-40 | lab | — | protocols/mieru | |
| mieru-le-48 | lab | — | protocols/mieru | |
| mieru-le-56 | lab | — | protocols/mieru | |
| socks | lab | — | protocols/socks | never random public SSH/SOCKS |
| http-proxy | lab | — | protocols/http | |
| https-proxy | lab | — | protocols/http | |
| ssh | lab | — | protocols/ssh | key+password test accounts |
| masque-connect-udp | oos | — | — | |
| tailscale | oos | — | — | |
| openvpn | oos | — | — | |
| ssr | oos | — | — | detect/reject only |

## Tooling map

| Piece | Path |
| --- | --- |
| Catalog | `tests/battle/public-sources.json` |
| Catalog gate | `scripts/battle/check_public_sources_catalog.sh` |
| Fetcher | `scripts/battle/fetch_public_sources.py` |
| Parser CLI | `swift run BattleParse` in `tests/VPNDirectParserPackage` |
| Orchestrator | `scripts/battle/run_battle_tests.sh` |
| Reports | `artifacts/battle/` (gitignored) |
| Sanitized goldens | `tests/fixtures/public-derived/` |
| Evidence schema | `interop/evidence/BATTLE_RUN_SCHEMA.json` |
| Workflow | `.github/workflows/public-battle.yml` |

## Required vs optional CI

- **Required:** catalog JSON validity (no network).
- **Optional (scheduled / workflow_dispatch):** fetch + parse + report artifacts. Dead sources do not fail the job unless golden sanitized fixtures regress.
