# Final Implementation Plan

Date: **2026-09-07**  
Companion: [`FINAL_IMPLEMENTATION_AUDIT.md`](FINAL_IMPLEMENTATION_AUDIT.md), [`../compatibility/COMPATIBILITY_IMPLEMENTATION_PLAN.md`](../compatibility/COMPATIBILITY_IMPLEMENTATION_PLAN.md).

## Current streams (active)

| Stream | Goal | Status / next |
| --- | --- | --- |
| **A — Panel corpus** | Fixtures + dossiers | **DONE** researched + fixtures; `fixture_pass` only after live exports |
| **B — Fail-closed policy** | Unknown critical | **DONE** XCTest + CompatibilityFieldPolicy on Remnawave unknown_critical |
| **C — Subscription HTTP** | ETag / headers | **DONE** If-None-Match / 304; fingerprint lab still live |
| **D — Interop labs** | Runnable panels | Scaffolds ready — need `.env` + live export evidence |
| **E — Device** | iPhone qualification | Schema + RSS hint ready — need physical device |
| **F — Clash depth** | Nested YAML | Hardened subset parser (no Yams); SPM optional later |
| **G — XHTTP / CDN** | Extras | Sibling + `extra` merge; invented keys fail-closed |
| **H — Release honesty** | Gates | `prepare_core` + matrix sync + Swift tests in `check-fixtures` |

## Dependency order (remaining)

```text
D live lab export (interop/panels)  →  E device evidence  →  matrix/panel status → tested
```

## P0 (immediate)

- [x] Deep dossiers for 12 panels  
- [x] Sanitized fixtures under `tests/fixtures/panels/`  
- [x] `core/panel-compatibility.json` researched + fixtures flags  
- [x] `interop/panels/{…}/` scaffolds  
- [x] Executable Swift checks: Remnawave / 3x-ui / marzban / unknown_critical / AWG (`make check-swift-parser-tests`)  
- [x] `prepare_core` overlays before parser execution / CI  
- [ ] Pin at least one lab VERSION and produce first live `evidence/` file  

## P1

- [ ] Remnawave Response Rules matrix lab (all body types including BLOCK/404/451)  
- [ ] Marzban OpenAPI create-user automation  
- [ ] Hiddify + Libertea VPS labs (install-script pinned)  
- [ ] Optional: Yams SPM for full Clash YAML  

## P2

- [ ] Device qualification pack (fill `docs/device` + `interop/evidence`)  
- [ ] Promote selected panels to `tested`  
- [ ] Tier-2 engines remain out_of_scope for Core 1.x product claims  

## Non-goals

- Claiming panel ≡ supported from dossiers alone  
- Shipping admin panel APIs inside the iOS app  
- OpenVPN / SoftEther / Tailscale / MASQUE CONNECT-UDP as Core 1.x features  
