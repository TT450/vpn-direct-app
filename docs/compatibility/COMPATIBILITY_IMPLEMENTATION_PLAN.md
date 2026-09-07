# Compatibility Implementation Plan

## Milestones (dependency order)

| # | Milestone | Depends | Goal |
| --- | --- | --- | --- |
| 1 | Source research KB | — | docs/compatibility/* + version pins |
| 2 | Normalized extensions | 1 | `rawExtensions` + field classifier fail-closed |
| 3 | Subscription HTTP | 1 | full header contract + ETag hooks |
| 4 | Panel fingerprint profiles | 2–3 | activate by headers/body, not domain |
| 5 | Clash fuller proxy parse | 2 | nested + more fields; YAML lib later |
| 6 | Xray variants | 2 | no silent node drop; preserve stream extras |
| 7 | Protocol edge cases | 2,6 | XHTTP extras, AWG strings, HY obfs |
| 8 | Mieru runtime | — | **DONE** v1.0.6 overlays |
| 9 | Panel fixtures corpus | 1 | tests/fixtures/panels/* |
| 10 | Protocol fixtures | 7 | expand regression |
| 11 | API automation | 9 | create-user/export scripts |
| 12 | Live panel lab | 11 | interop/panels docker |
| 13 | Fuzz | 2,9 | generative unknown fields |
| 14 | Device qualification | 12 | evidence files |
| 15 | Production gate | 9,14 | panel claims ↔ fixtures/evidence |

## P0 (this tranche — code now)

- [x] Audit + plan docs  
- [x] `NormalizedNode.rawExtensions` + `CompatibilityFieldPolicy`  
- [x] VLESS unknown query / unknown transport fail-closed  
- [x] SubscriptionMetadata: announce, supportURL, profileURL, updateInterval, routing, provider, etag  
- [x] `CompatibilityProfile` fingerprint from headers/body  
- [x] XrayJSONAdapter: convert-miss diagnostics; stream/settings → extensions  
- [x] Panel fixture skeleton (remnawave/3x-ui headers) + dossiers  
- [x] `core/panel-compatibility.json` + `check_panel_compatibility.sh`  
- [x] README Compatibility link  

## P1 (next)

- Marzban / Marzneshin / PasarGuard / Hiddify / Libertea / s-ui deep dossiers + fixtures  
- XHTTP extra mapping (TheTochka)  
- Real YAML parser dependency evaluation  
- interop/panels docker-compose templates  

## P2

- Tier-2 engines (Tailscale, OpenVPN, …) remain out_of_scope for Core 1.x product claims  
- Long-tail panels / rare aliases  

## Honesty rules

- Do not mark panel `implemented` without fixtures + unknown-field policy.  
- Do not mark `tested` without interop + device evidence.  
- Do not stop after scaffolding — continue until P0 code lands.
