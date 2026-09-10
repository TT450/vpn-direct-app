# VPN Direct Documentation

Engineering docs map for **v1.0.11.63** (marketing **1.0.11**, TestFlight build **63**). Keep in sync with the GitHub README quick links.

## Start here

| Document | Use it for |
| --- | --- |
| [`../WHATS_NEW.md`](../WHATS_NEW.md) | Latest release notes (`v1.0.11.63`) |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Full version history |
| [`TESTFLIGHT.md`](TESTFLIGHT.md) | TestFlight beta + inviting testers (build **63**) |
| [`core/ARCHITECTURE.md`](core/ARCHITECTURE.md) | Core + Apple import pipeline (current) |
| [`core/BUILDING.md`](core/BUILDING.md) | Reproducing Libbox and Apple builds |
| [`core/PROTOCOL_MATRIX.md`](core/PROTOCOL_MATRIX.md) | Authoritative protocol status |
| [`../core/protocol-matrix.json`](../core/protocol-matrix.json) | Machine-readable matrix (CI / release gate) |
| [`core/RELEASE_BLOCKER_LEDGER.md`](core/RELEASE_BLOCKER_LEDGER.md) | Open vs verified release blockers |
| [`compatibility/README.md`](compatibility/README.md) | Panels, ecosystems, HTTP subscription quirks |
| [`compatibility/COMPATIBILITY_MATRIX.md`](compatibility/COMPATIBILITY_MATRIX.md) | Panel × protocol support map |
| [`battle/BATTLE_SOURCE_PLAN.md`](battle/BATTLE_SOURCE_PLAN.md) | Public harvest catalog plan |
| [`device/IPHONE_QUALIFICATION.md`](device/IPHONE_QUALIFICATION.md) | Device evidence checklist |
| [`device/IPHONE_INSTALL_2026-09-07.md`](device/IPHONE_INSTALL_2026-09-07.md) | Wi-Fi install recipe (SFI + `devicectl`) |
| [`device/IPHONE_INSTALL_2026-09-08.md`](device/IPHONE_INSTALL_2026-09-08.md) | Wi-Fi install evidence (v1.0.10) |
| [`device/IPHONE_INSTALL_2026-09-08_BUILD63.md`](device/IPHONE_INSTALL_2026-09-08_BUILD63.md) | TestFlight **1.0.11 (63)** upload evidence |
| [`../interop/README.md`](../interop/README.md) | Interop lab scaffolds |
| [`core/DONORS.md`](core/DONORS.md) | Upstream / donor source tracking |
| [`core/LICENSE_AUDIT.md`](core/LICENSE_AUDIT.md) | Dependency / license notes |
| [`../ROADMAP.md`](../ROADMAP.md) | Public product roadmap |
| [`../SUPPORT.md`](../SUPPORT.md) | How to get help |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | PR / fixture / matrix rules |

## Supporting core notes

| Document | Use it for |
| --- | --- |
| [`core/REMOTES.md`](core/REMOTES.md) | Git remotes / submodule pins |
| [`core/PANIC_BOUNDARY.md`](core/PANIC_BOUNDARY.md) | What must never crash the NE |
| [`core/LEGACY_OUTBOUND_WRITERS.md`](core/LEGACY_OUTBOUND_WRITERS.md) | Remaining prebuilt-outbound writers |
| [`core/REMEDIATION_EXECUTION_PLAN.md`](core/REMEDIATION_EXECUTION_PLAN.md) | Living remediation plan (REQ coverage) |
| [`brand/README.md`](brand/README.md) | Brand assets |

## Support vocabulary

```text
parsed → compiled → validated → interop-tested → device-tested → production (`tested`)
```

A parser or builder alone is not proof of production support. Rows marked `parser+runtime` mean import + Core registration exist; live tunnel evidence is still required for `tested`.

Historical one-shot audit/plan markdown from early Core 0.1 landings was removed in v1.0.10 — status lives in the matrix, ledger, and CHANGELOG.
