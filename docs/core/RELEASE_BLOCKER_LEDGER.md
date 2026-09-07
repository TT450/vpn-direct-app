# RELEASE BLOCKER LEDGER

Statuses: `OPEN` | `IMPLEMENTED_UNVERIFIED` | `VERIFIED` | `EXTERNAL_BLOCKED`

Source of truth: `docs/core/REMEDIATION_REQUIREMENTS.json` (217 requirements).

## Summary

- TOTAL: 217
- VERIFIED: 216
- EXTERNAL_BLOCKED: 1
- OPEN: 0
- IMPLEMENTED_UNVERIFIED: 0

## EXTERNAL_BLOCKED

- **REQ-DEVICE-tunnel-start**: needs interactive VPN permission + live config on device E4788B50…; install/launch already PASS

## Gates

- `scripts/check_remediation_plan_coverage.py` → UNPLANNED=0
- `scripts/check_field_coverage.py` → FIELD COVERAGE OK
- Libbox/SFI build + Wi-Fi install/launch: see `docs/device/IPHONE_INSTALL_2026-09-07.md`
- Packet Tunnel / handshake: EXTERNAL until interactive VPN permission + battle keys

