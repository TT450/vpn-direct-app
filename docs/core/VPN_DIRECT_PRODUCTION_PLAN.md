# VPN Direct Production Plan

Dependent milestones. Do not mark a later milestone complete while earlier P0 gates fail.

## Milestone 1 — Capability correctness

- Remove `with_mieru` from profiles until runtime exists
- Compile-time proofs for MASQUE / VLESS encryption / Gecko
- CapabilityJSON is source of truth; Swift decodes only
- Fix gomobile SHA detection; mandatory AWG submodule must fail hard
- CI asserts `mieru=false` for default iOS profile

**Exit:** no capability can claim an unimplemented feature.

## Milestone 2 — Normalized model

- `NormalizedNode` + extensible protocol/transport/security/obfuscation strings
- `VPNDirectParser` + diagnostics (`total/parsed/unsupported/malformed`)
- Route subscription flow: parser → capability resolve → builder

**Exit:** VLESS path works through NormalizedNode without behavior regression.

## Milestone 3 — Universal parser

- URI schemes: vmess/trojan/ss/hy2/tuic/anytls/wg/awg/socks/http/ssh
- Content detection: URI list, base64, sing-box JSON, Xray JSON (no silent alternate), Clash/Mihomo YAML

## Milestone 4 — Core completion

- Mieru TCP/UDP/LE behind `with_mieru` only after memory budget path exists
- Capability true only when outbound registered

## Milestone 5 — Validation / errors / logging

- `VPNDirectConfigValidator`
- `VPNDirectCoreError` v2
- `VPNDirectLog` + `VPNDirectRedactor`
- Panic-safety documentation/tests at Go↔Swift boundary

## Milestone 6 — Regression / fuzz

- Expanded fixtures + `sing-box check` / Libbox validate
- Parser fuzz smoke

## Milestone 7 — Interop lab

- `interop/{xray,amnezia,hysteria,tuic,anytls,mieru,masque}`
- Handshake + TCP/UDP/DNS where applicable

## Milestone 8 — iOS qualification

- Device matrix: reconnect, Wi-Fi↔cellular, RSS, connect latency
- Status `device_passed` / `production` only after evidence

## Milestone 9 — Production CI

- Multi-scheme builds, artifact SHA256, capabilities.json upload

## Milestone 10 — Release gate

- `scripts/check_production_ready.sh`
- Machine-readable `core/protocol-matrix.json`

## Production definition (protocol)

A protocol is `production` only if parser, config build, Core validate, NE start, handshake, TCP/(UDP), DNS, reconnect, memory acceptable, interop PASS, and device PASS all succeed.
