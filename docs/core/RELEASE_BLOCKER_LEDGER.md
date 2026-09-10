# RELEASE BLOCKER LEDGER

Statuses: `OPEN` | `IMPLEMENTED_UNVERIFIED` | `VERIFIED` | `EXTERNAL_BLOCKED`

Source of truth: `docs/core/REMEDIATION_REQUIREMENTS.json` (217 requirements).

## Summary (post TheTochka + ChatGPT honesty merge)

- TOTAL: 217
- EXTERNAL_BLOCKED: 1 (`REQ-DEVICE-tunnel-start`)
- Code-completable OPEN items from post-v1.0.9 audit are being closed surgically; do not cite the old blanket `216 VERIFIED / OPEN=0` without path+CI agreement.

## Landed in this merge (IMPLEMENTED → verify via parser tests)

- **Graph identity (TheTochka + ChatGPT):** no display-name leaf collapse; tags uniquify from names (`Germany` / `Germany-2`); ambiguous *referenced* names fail closed; xrayTag/loc-index authoritative.
- **XRAY leaf UI names (TheTochka):** single-leaf profiles keep `remarks`; multi-leaf prefer xray tag.
- **Per-profile fingerprint dedupe:** retained richer-than-Tochka `leafFingerprint` (not host:port-only).
- **Strategies:** `random` rejected; `fallback` → urltest + explicit Libertea-compat warning.
- **HY/HY2 / Mieru / XHTTP mapper / Reality stream-one quirk / outbound equality / portable classifier symlink:** from ChatGPT branch, with Tochka stream-one quirk kept.
- **Tunnel import paths (2026-09-08):** OpenVPN `.ovpn`, OpenConnect JSON/XML, Tailscale endpoint JSON, MASQUE CONNECT-UDP outbound (`type: masque-connect-udp`). Parser/UI green; **Libbox rebuild required** for CONNECT-UDP capability flip + `with_tailscale` Darwin tag before device runtime.

## EXTERNAL_BLOCKED

- **REQ-DEVICE-tunnel-start**: needs interactive VPN permission + live config on device E4788B50…; install/launch already PASS (`docs/device/IPHONE_INSTALL_2026-09-07.md`)

## Gates

- `scripts/check_remediation_plan_coverage.py` → UNPLANNED=0
- `scripts/check_field_coverage.py` → FIELD COVERAGE OK
- Parser package: HysteriaSemantic / MieruSemantic / GraphIdentity + existing suites
- Libbox/SFI build + Wi-Fi install/launch evidence retained
- Packet Tunnel / handshake: EXTERNAL until interactive VPN permission + battle keys
