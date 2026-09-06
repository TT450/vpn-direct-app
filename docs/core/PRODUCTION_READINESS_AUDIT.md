# Production Readiness Audit

Date: 2026-09-07  
Repo tip audited against live code (not README claims).  
Overall full-plan readiness: **~50–55%**. Core foundation: **~80–85%**.

Status legend: `DONE` | `PARTIAL` | `MISSING` | `BROKEN` | `UNPROVEN`

| Block | Status | Evidence |
| --- | --- | --- |
| Core architecture | DONE | `core/sing-box` submodule, overlays, VERSION pins |
| Libbox build pipeline | DONE | `scripts/build_libbox.sh`, Makefile targets |
| Core pinning | DONE | `core/VERSION` + submodule SHA |
| gomobile pinning | PARTIAL | sagernet `v0.1.12`; SHA detection still looks for `golang.org/x/mobile` |
| Build profiles | PARTIAL | ios / minimal / full exist; **Mieru tag removed from full until runtime** |
| Capability Registry | PARTIAL | fail-closed ABI OK; MASQUE/PQ/Gecko compile-proven; interop still UNPROVEN |
| ABI negotiation | DONE | magic + API v1 + CapabilityJSON |
| XHTTP | PARTIAL | builder + fail-closed; interop UNPROVEN |
| VLESS encryption / PQ | PARTIAL | builder + gate; capability soft; interop UNPROVEN |
| AWG 1/2/3.0/3.1 | PARTIAL | multi-peer parser + fields; versions hardcoded in Go; interop UNPROVEN |
| MASQUE CONNECT-IP | PARTIAL | builder + soft capability; interop UNPROVEN |
| Hysteria2 Gecko | PARTIAL | tag const; not compile-proven |
| Mieru | MISSING (runtime) | tag stripped; capability false until port |
| Subscription parser | PARTIAL | NormalizedNode + VLESS adapter; other schemes skipped |
| Xray import | PARTIAL | VLESS-only filter |
| Clash / Mihomo import | MISSING | — |
| WireGuard / AWG import | PARTIAL | AWG `.conf` standalone; not wired as universal subscription |
| NormalizedNode | PARTIAL | skeleton + VLESS adapter; universal parsers pending |
| Validation API | PARTIAL | raw `LibboxCheckConfig` only |
| Error model | PARTIAL | 3 cases; not v2 |
| Logging / redaction | MISSING | OSLog helper only |
| Crash safety | UNPROVEN | no dedicated boundary tests |
| NetworkExtension | DONE | existing SFI/Extension stack |
| Interop automation | MISSING | `interop/README.md` only |
| Regression fixtures | PARTIAL | small corpus; shape checks only |
| Fuzz | MISSING | — |
| CI baseline | PARTIAL | fixtures+abi+libbox+SFI; no sing-box check / interop |
| Memory / CPU / binary size | MISSING | — |
| Real-device qualification | UNPROVEN | Matrix says planned |

## Truth rules

- `builder exists` ≠ `production`
- Capability `true` requires compile-time and/or runtime proof
- Protocol matrix statuses must match this audit
