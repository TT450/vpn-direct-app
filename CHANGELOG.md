# Changelog

All notable changes to VPN Direct (Apple client) are documented here.

## [1.0.11.87] — 2026-09-09

### Direct-first UI + locations (build 87)

- Tabs: Главная · Локации · Управление · Профиль; ad free-flow removed
- Plans / constructor / pricing engine; sales path through payment method (guest OK)
- Locations catalog (seed + cache/ETag); Direct-only servers via `bot.vpn-direct.com`
- `DirectBackend` ownership: never Remnawave from client; imports stay separate
- Management page wired to Direct entitlement; AppBar back chrome + page top inset

## [1.0.11.81] — 2026-09-09

### Soft-remove, labels, picker (TestFlight build 81)

- Soft-remove («Убрать из клиента») clears home selection (`selectedProfileID = -1`); no auto-activate next import
- Country labels only (no capital substitution); cached catalog + faster server picker
- Full country flag asset set across app / widgets
- Backup branch snapshot aligned with this release tip

## [1.0.11.63] — 2026-09-08

### Widgets + tunnel reliability (TestFlight build 63)

- Home Screen widget toggles VPN in-place (`ToggleVPNWidgetIntent`) — no app open on tap
- Small widget: larger power button with balanced padding; labels **Включен** / **Включить**
- Live NE status in widget extension (`packet-tunnel` entitlement); timeline reload on connect/disconnect
- Control Center control: non-throwing value provider; App Store widget profile refreshed with Network Extension
- Imported subscriptions: no Free/Premium expire gate; Russian bypass uses `http_client` → `proxy` only
- Packet tunnel: removed WidgetKit/Control Center reloads that killed `command.sock`
- Guard against early Control Center stop right after dial

## [1.0.11] — 2026-09-08

### DirectUI + widgets

- Home Screen / Lock Screen / Control Center widgets (VPN Direct branded toggle + status)
- Connection mode **5G** (renamed from «Антиблокировка»; stored preference migrates)
- Page chrome: unified heading size; Home kicker `КЛИЕНТ / VPN`; status dot after title
- Subscriptions: vertical-only ScrollView (no horizontal pan); card text constraints
- Import menu: QR, clipboard, URL, file, paste config (`DirectImportViews` / local importer)
- Server picker: full-width Ping; offline TCP endpoint ping + connected urlTest
- Fastlane `ios release` lane: ASC API key + TestFlight upload path documented in `docs/TESTFLIGHT.md`

## [1.0.10] — 2026-09-08

### Tunnel import + CONNECT-UDP

- OpenVPN `.ovpn` / OpenConnect / Tailscale endpoint JSON import (File + paste → graph `endpoints`)
- MASQUE CONNECT-UDP (RFC 9298) Core outbound `masque-connect-udp` + Swift adapter/capability
- Darwin `build_libbox`: re-enable `with_tailscale` (+ omit tags); CONNECT-UDP needs Libbox rebuild for capability flip
- Public harvest: ML-KEM samples (barry-far); Code-Leafy configs still 404
- Docs: architecture/matrix/compatibility refreshed; removed stale Core 0.1 audit/plan drafts
- Tests: `TunnelEndpointImportTests`

## [1.0.9] — 2026-09-07

### Production remediation release

- WireGuard / AmneziaWG production graph uses Core `endpoints` (multi-peer + AWG 2/3.x fields); BattleParse parity with production builder
- Fail-closed parsers/builders: silent drops removed; Xray balancers/fingerprint; Clash groups; typed extensions
- Subscription HTTP: generic-first identity, redirect origin strip, streamed size cap, Keychain HWID durability
- Content detector: structural JSON/Xray object/base64 re-detect; panel fixtures + provenance
- Libbox/prepare_core harden; SFI Wi-Fi install/launch on physical iPhone (tunnel still needs interactive VPN)
- Traceability: `docs/core/REMEDIATION_REQUIREMENTS.json` + plan coverage checker (`UNPLANNED=0`)

## [1.0.6.1] — 2026-09-07

### Core shipping fix

- Mieru protocol sources live in `core/overlays/sing-box/` and are applied onto the public `sing-box-lx` pin (`v1.14.0-lx.35`) by `scripts/apply_singbox_overlays.sh`
- Submodule points at fetchable `Leadaxe/sing-box-lx` again (no private fork push required)
- `bootstrap_core.sh` / `build_libbox.sh` / ABI & production checks invoke overlay apply

## [1.0.6] — 2026-09-07

### Battle-key qualification ready

- Mieru Core outbound/inbound behind `with_mieru`; Swift builder aligned to mbox JSON
- Clash nested Reality/WS/gRPC/plugin opts; detector schemes for naive/shadowtls/http-proxy
- Executable `check_parser_execution.sh` + panic-boundary doc; interop env templates
- Matrix/docs honest: `parser+runtime` / qualification-ready — not fake `tested`

## [1.0.5] — 2026-09-07

### What's New

See [`WHATS_NEW.md`](WHATS_NEW.md).

#### Universal import + honesty gate
- Content detector; multi-scheme URI parsers; Clash YAML; Xray multi-proto leaves
- Validator / redaction; `check_production_ready.sh`; `protocol-matrix.json`
- Docs: README / Architecture / Matrix / Build / Contribute refreshed for post-harvest state

## [1.0.4] — 2026-09-07

### What's New

TheTochka Compatibility Harvest P0: NormalizedSubscription / Location, HY2, Remnawave balancers/Auto, per-profile dedupe, dialerProxy→detour.

## [1.0.3] — 2026-09-07

Happ-first subscription UA, Keychain HWID migration, CI ExtensionProfile deinit fix.

## [1.0.2] — 2026-09-07

GitHub Core polish + capability/NormalizedNode skeleton tranche.

## [1.0.1] — 2026-09-06

Core 0.1 hardening baseline (no silent XHTTP downgrade, fail-closed capabilities).

## [1.0.0] — 2026-09-06

- Initial public GPLv3 source offer for VPN Direct (Apple)
