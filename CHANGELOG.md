## [1.0.11.153] — 2026-09-20

### Auth hardening + logout wipe (build 153)

- Logout/delete/401 clears premium entitlement, traffic, location caps, and Direct sub URL
- Session token + device id in Keychain; bot-confirm poll cancellation; token-only auth
- Account-switch warning for all login methods; email OTP resend cooldown
- TestFlight **1.0.11 (153)**

# Changelog

All notable changes to VPN Direct (Apple client) are documented here.

## [1.0.11.112] — 2026-09-15

### TestFlight rebuild (build 112)

- Public Apple tip cleaned on `main` (Harmony-only commits moved off default branch)
- TestFlight **1.0.11 (112)** — same client surface as 111, new build number
- No private backend clients or secrets

## [1.0.11.111] — 2026-09-14

### Legal center + account deletion (build 111)

- Clearer email/password login errors
- Legal docs, account deletion, App Store rate prompt
- TestFlight **1.0.11 (111)**

## [1.0.11.109] — 2026-09-13

### Privacy disclosure + renew fixes (build 109)

- Privacy disclosure gate before VPN Connect (Apple Guideline 5.4); decline closes without connecting
- Renew checkout prefers last-paid / active entitlement over browsed unpaid catalog plans
- Management shows active tariff (not checkout cart) after Buy → Back
- TestFlight **1.0.11 (109)**

## [1.0.11.108] — 2026-09-13

### Balance / checkout UI (build 108)

- Top-up sheet chrome aligned with other sheets; sticky header above packs list
- Balance amounts shown in USD only; RUB for external payment methods
- Interactive Apple purchase waiting states; payment CTA inverted + animated
- Payment balance card shows actual balance only

## [1.0.11.107] — 2026-09-13

### TestFlight IAP fix (build 107)

- Bakes the correct VPN Direct RevenueCat App Store public key for credit packs
- No public API/backend changes in this build

## [1.0.11.106] — 2026-09-13

### Checkout return-host helper (build 106)

- Shared `checkoutReturnHostAllowed` helper for exact host / proper subdomain checks
- External WebView `/success` continues to be a wait/poll signal only (not payment proof)

## [1.0.11.105] — 2026-09-13

### Checkout host allowlist hardening (build 105)

- External WebView `/success` matches only exact host or proper subdomain (no raw `hasSuffix`)
- Requires `https`; navigation remains a wait/poll signal — backend status is still authoritative
- RevenueCat `nonSubscriptions` API shape fix for current SDK

## [1.0.11.104] — 2026-09-13

### Resilient Apple credit UX (build 104)

- Apple top-up states: confirming purchase → funds processing → credited
- No false “purchase failed” when Apple already confirmed and ledger sync is pending
- Pending credit survives app restart; Sync Funds retries idempotent credit by transaction ID
- Currency-aware credit-pack recommendation; Rapira ask + markup for ₽↔$ display
- Checkout auto-continues after successful top-up when balance covers the tariff

## [1.0.11.103] — 2026-09-13

### Balance checkout + profile ledger (build 103)

- Payment method: pay from in-app balance or other (webview) methods
- Insufficient balance opens Apple credit-pack top-up; success returns to checkout or Profile → Balance
- Profile → Balance screen with current amount (`₽ / $`) and transaction history
- Shared `DirectMoney` presentation for tariffs / constructor / checkout
- Public RevenueCat facade for `direct.credits.*` consumables (empty SDK key on GitHub; local hooks fill it)
- `.addOns` route remains normal add-ons; top-up uses a dedicated balance flow

## [1.0.11.87] — 2026-09-09

### Direct-first UI + locations (build 87)

- Tabs: Главная · Локации · Управление · Профиль; ad free-flow removed
- Plans / constructor / pricing engine; sales path through payment method (guest OK)
- Locations catalog (seed + cache/ETag); Direct-only servers in the product catalog
- Direct ownership rules: imports stay separate from Direct catalog
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
