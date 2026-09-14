# Changelog

All notable changes to the **VPN Direct HarmonyOS NEXT platform branch** are documented here. Historical Apple release entries remain preserved below for Core provenance.

## [HarmonyOS platform] — 2026-09-14

### Professional platform foundation

- Dedicated HarmonyOS NEXT project presentation and repository documentation
- Native ArkTS / ArkUI platform direction
- `VpnExtensionAbility` + HarmonyOS TUN architecture
- N-API native Core boundary
- HarmonyOS architecture, build and real-device qualification guides
- Dedicated HarmonyOS GitHub hero and platform badges
- Apple-only TestFlight / Network Extension presentation removed from the branch README
- Existing VPN Direct Core lineage preserved: `0.1.0` / `sing-box-lx v1.14.0-lx.35`

> Source integration is not presented as device-tested until DevEco compilation and real-device evidence exist.

## Historical Apple releases

The entries below are retained because the branch inherits the shared repository/Core history. They are not HarmonyOS runtime requirements.

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

- Soft-remove clears home selection; no auto-activate next import
- Country labels only; cached catalog + faster server picker
- Full country flag asset set across app / widgets

## [1.0.11.63] — 2026-09-08

### Widgets + tunnel reliability (build 63)

- Home Screen / Lock Screen / Control Center widgets
- Live Network Extension status and in-place VPN toggle
- Imported subscriptions and tunnel reliability fixes

## [1.0.11] — 2026-09-08

### DirectUI + widgets

- Direct-first navigation, import menu and server picker
- Home / Lock Screen / Control Center integration

## [1.0.10] — 2026-09-08

### Tunnel import + CONNECT-UDP

- OpenVPN / OpenConnect / Tailscale endpoint import
- MASQUE CONNECT-UDP Core outbound and Swift capability

## [1.0.9] — 2026-09-07

### Production remediation release

- WireGuard / AmneziaWG production graph
- Fail-closed parsers/builders and Core hardening
- Subscription HTTP and content-detector hardening

## [1.0.6.1] — 2026-09-07

### Core shipping fix

- Mieru overlays applied to public `sing-box-lx v1.14.0-lx.35`
- Core bootstrap/build and ABI checks hardened

## [1.0.6] — 2026-09-07

### Battle-key qualification ready

- Mieru Core runtime behind `with_mieru`
- Clash nested options and protocol parser hardening

## [1.0.5] — 2026-09-07

### Universal import + honesty gate

- Content detector and multi-scheme URI parsers
- Clash YAML and Xray protocol support
- Production readiness validation

## [1.0.4] — 2026-09-07

TheTochka compatibility harvest P0: NormalizedSubscription / Location, HY2, Remnawave balancers/Auto, per-profile dedupe and dialerProxy → detour.

## [1.0.3] — 2026-09-07

Happ-first subscription UA, Keychain HWID migration and CI ExtensionProfile deinit fix.

## [1.0.2] — 2026-09-07

GitHub Core polish and CapabilityJSON / NormalizedNode baseline.

## [1.0.1] — 2026-09-06

Core 0.1 hardening baseline with fail-closed capabilities.

## [1.0.0] — 2026-09-06

Initial public GPLv3 source offer for VPN Direct.
