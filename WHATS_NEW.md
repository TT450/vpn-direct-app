# What's New — VPN Direct 1.0.4

Release date: 2026-09-07  
Git tag: `v1.0.4`

## App Store / short What's New

- Remnawave / Happ subscriptions keep country locations and Auto (no more “one VLESS only”)
- Hysteria / Hysteria2 share links and XRAY JSON supported
- Same server in Auto and a country no longer deletes the country row
- Multi-hop cascades via dialerProxy → detour restored from TheTochka compatibility harvest

## Engineering detail

### Compatibility Harvest P0 (TheTochka `dev`)
- `NormalizedSubscription` → `NormalizedLocation` → `NormalizedNode`
- `XrayJSONAdapter`: all VLESS + HY2 leaves, per-profile dedupe, no skip of Автовыбор
- `SingBoxGraphBuilder`: per-location urltest + global `auto` over leaves
- `HysteriaShareLinkParser` + Xray Hysteria conversion (ignore uTLS on QUIC)
- `dialerProxy` → `detour` end-to-end
- Fixtures + `scripts/check_subscription_graph.sh`

### Still deferred
- Full Universal Parser (TUIC/AnyTLS/Clash…)
- XHTTP Yandex CDN mapping (P1)
- Interop lab / device qualification / Mieru

See also: `docs/core/THETOCHKA_COMPATIBILITY_HARVEST.md`, `CHANGELOG.md`.
