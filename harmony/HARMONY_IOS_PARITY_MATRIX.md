# VPN Direct HarmonyOS ↔ iOS parity matrix

Source of truth: iOS SwiftUI at the latest parity baseline (e334e20990ecec9e0f6cbec960ae2657dc25656d / later DirectAccountUtility and Legal sources where those supersede it).

For every screen the review criteria are: exact copy, typography/weight, frame/minHeight, padding/margins, alignment, colors/opacity, borders/strokes, shadows, icon asset/size/weight, state, loading/error/empty states, animation, haptic interaction, navigation and presentation style.

## Primary pages
- Home — `HomePage.ets` + `DialView.ets`: verify dial geometry, pointer, labels, telemetry, server row.
- Locations — `LocationsPage.ets`: verified against `DirectServersPage.swift`; cards are 70 high, 8 gap, search 43, current card 14 inset, server rows 58.
- Management — `ManagementPage.ets`: verified against `DirectManagementPage.swift`; Direct subscription block, renewal CTA, usage, settings, imported subscriptions.
- Profile — `ProfilePage.ets`: legal section now contains all 8 iOS documents, About block, App Store rating and account deletion; utility routes are separate.

## Detail screens
- Access
- Subscriptions
- Plans
- Constructor
- Payment
- Balance
- Balance Top Up
- Security
- Connection
- Diagnostics
- Activity
- System
- On-Demand
- Account
- Auth Login / Email / Code / Register / Recovery / Phone / Bot / Success
- Connection Report
- Profiles
- Import File / Text / Clipboard / Config
- Devices / Payment History / Promo / Support / Account Linking
- Legal / Privacy / About

## Presentation rules
- Non-sheet detail flows own their Swift-like header; the global Harmony app header must not be rendered simultaneously.
- Utility/server/profile sheets use `bindSheet`; `radius: 0`, fixed header inside the sheet, scrolling only below that header.
- Text fields are square (`borderRadius(0)`), use iOS field geometry, and never inherit a platform rounded shape.
- ArkTS `build` / `@Builder` contains UI expressions only. Derived values belong in methods/state.
- No TypeScript type predicates (`x is T`) in ArkTS.
- Every `VpnServerSelection.set` call supplies `id`, `displayName`, and `countryCode`.
- No Free/Premium user-facing access mode is reintroduced.

## Known final visual validation requirement
Source-level parity is not the same as pixel parity. Final 100% verification requires Harmony screenshots at the same viewport as iOS and direct image comparison for every screen/state.