# RELEASE BLOCKER LEDGER

Statuses: `OPEN` | `IMPLEMENTED_UNVERIFIED` | `VERIFIED` | `EXTERNAL_BLOCKED`

Source registry: `docs/core/REMEDIATION_REQUIREMENTS.json` (217 canonical requirements).

> The v1.0.9 close-out summary (`216 VERIFIED / OPEN=0`) is intentionally reopened by the post-release HEAD audit. A requirement is not VERIFIED merely because the generated registry says so; the current production path and CI evidence must agree.

## Current post-v1.0.9 status

The exact totals are being recalculated while the master-prompt re-audit continues. Until the registry is reconciled, do **not** publish the old `216 VERIFIED / OPEN=0` counters as release evidence.

### VERIFIED evidence retained

- Exact pinned Core preparation: `Leadaxe/sing-box-lx v1.14.0-lx.35` / SHA `5ea79ce2ba369153aeecc5fea273e0c05d30469d`.
- iOS app build/install/launch evidence exists in `docs/device/IPHONE_INSTALL_2026-09-07.md`.
- **iPhone live VLESS runtime is manually VERIFIED by the product owner**: real subscription URL imported, VPN connected in the app, tunnel came up and traffic worked. This verifies the app→NetworkExtension→Libbox→TUN→VLESS path for that tested VLESS profile only; it is not evidence for every protocol/variant.
- Current remediation CI `Fixtures + ABI overlays` passed after replacing the non-portable parser-package symlink and adding stricter Hysteria/Mieru tests.

### OPEN / IMPLEMENTED_UNVERIFIED from post-release audit

- **Graph identity**: v1.0.9 deduplicated leaves by display name. Remediation branch now builds every endpoint instance independently and resolves ambiguous display-name references fail-closed. Await final SFI/Core regression evidence.
- **Graph strategy fidelity**: v1.0.9 mapped `random → selector` and `fallback → urltest`. Remediation branch now rejects both unless a faithful pinned-Core mapping is implemented. Await final regression evidence.
- **Hysteria/HY2 normalization**: remediation removes invented HY1 port/bandwidth defaults and preserves advanced HY2 source fields. Parser/Core tests pass; full iOS protocol runtime still not separately qualified.
- **Mieru normalization**: remediation requires explicit TCP/UDP and credentials and refuses fake `lowEntropy → traffic_pattern` coercion. Parser/Core tests pass; full Mieru LE/server_ports typed model remains open.
- **XHTTP**: pinned-field mapper and stricter Xray VLESS conversion are present, but generic normalized/builder field coverage and remaining defaults still require final audit.
- **Legacy `NormalizedNode.outbound` escape hatch**: still exists and can bypass the canonical typed builder path. Production writers must be inventoried/migrated before this requirement can be VERIFIED.
- **Typed shared models**: TLS / transport / multiplex / QUIC / Dial / DNS / routing are not yet fully represented as typed canonical models across every protocol.
- **Protocol exhaustive sweep** remains open for variants/settings not proven end-to-end by field assertions and exact pinned Core validation.
- **Panel exhaustive sweep** remains open where fixtures/matrices exist without full generator/source-derived semantic coverage.

### External/manual runtime scope

macOS, tvOS and iOS Simulator runtime qualification are intentionally **not release blockers for the current phone-first phase**. iPhone is the runtime priority.

Additional live handshakes for WG/AWG, HY/HY2, TUIC, AnyTLS, Mieru, MASQUE/WARP and other protocols remain manual/live evidence tasks after their code paths are ready. Lack of those live servers/credentials must not be used to mark code-completable parser/model/builder/test work as EXTERNAL_BLOCKED.

## Gates

- `scripts/check_remediation_plan_coverage.py` must remain `UNPLANNED=0` after registry reconciliation.
- `scripts/check_field_coverage.py` must pass against the actual production builder, not documentation only.
- Exact final config lifecycle remains `normalize/build → migrate → validate exact final JSON → launch`.
- `Core baseline` must be green for the remediation head, especially `Fixtures + ABI overlays`, Libbox build and **SFI** compile. SFM/SFT runtime qualification is deferred in the current iPhone-first phase.
- Final completion still requires `OPEN=0` and `IMPLEMENTED_UNVERIFIED=0` for all code-completable master-prompt requirements.
