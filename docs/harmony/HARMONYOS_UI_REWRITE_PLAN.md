# HarmonyOS NEXT UI — complete ArkTS rewrite plan

> **Branch:** `harmony-os-app`  
> **Scope:** rebuild the complete VPN Direct user interface in native ArkTS/ArkUI.  
> **Principle:** this is a clean HarmonyOS implementation, not a SwiftUI-to-ArkTS mechanical port.

## 1. Goal

Rebuild the entire VPN Direct interface from zero in ArkTS/ArkUI while preserving the product's user-facing behavior, navigation, account/subscription flows, VPN controls, server selection, legal information, and error states.

The SwiftUI implementation is the **behavioral/reference specification**. ArkUI is the **implementation target**. HarmonyOS-specific interaction patterns, lifecycle, typography, navigation, sheets/dialogs, accessibility, and responsive layout must be native to HarmonyOS NEXT.

The UI must remain independent from the VPN engine. Screens call a Harmony presentation/service layer; they never manipulate TUN file descriptors, N-API handles, or Core internals directly.

## 2. Non-negotiable architecture

```text
ArkUI pages/components
        ↓
Harmony presentation/state layer
        ↓
platform services / repositories
        ↓
VPN Direct shared product contracts
        ↓
VpnExtensionAbility + VpnConnection
        ↓
N-API bridge
        ↓
VPN Direct Core 0.1.0
        ↓
sing-box-lx v1.14.0-lx.35
```

### UI rules

- All UI is native ArkTS/ArkUI.
- No WebView-based app shell.
- No embedded HTML/CSS UI.
- No Swift/SwiftUI runtime dependency.
- No Android UI compatibility layer.
- No business logic hidden inside visual components.
- No fake VPN state: UI state must originate from the real Harmony VPN/Core state machine.
- No private backend URLs, credentials, signing material, or secrets in the public repository.
- Subscription/config data is treated as data; it cannot deliver executable code or native libraries.

## 3. Product surface to reproduce

The current iOS UI contains a substantial DirectUI surface. The rewrite must audit every SwiftUI view before declaring parity. The known primary surfaces include:

### Main navigation

1. **Home / VPN control**
   - connection status
   - primary connect/disconnect control
   - selected server/location
   - connection progress/failure states
   - active-session information
   - server picker entry point
   - imported/subscription state where applicable

2. **Locations / Servers**
   - location catalog
   - country flags/metadata
   - search
   - server list
   - ping/availability presentation
   - auto-selection
   - selected server state
   - server picker used from Home

3. **Plans / Service**
   - plan periods
   - tariff cards
   - current service state
   - renewal/service actions
   - checkout hand-off
   - loading, unavailable and error states

4. **Management / Subscriptions**
   - Direct service/subscription first
   - renewal/manage actions
   - third-party/imported subscriptions where supported
   - add/import flow
   - active/inactive/expired states

5. **Profile / Account**
   - account identity
   - sign-in/sign-out
   - account switching
   - account utilities
   - balance and transaction history
   - top-up flow where supported
   - application/legal section
   - account deletion

6. **Legal / Privacy**
   - privacy disclosure before first VPN activation
   - privacy information
   - terms/legal documents
   - app information/version
   - account deletion confirmation

### Secondary and modal surfaces

The audit must also cover the existing utility, advanced, access, balance, authentication, subscription import, server picker, constructor, management and confirmation views. These are not optional: a screen is considered migrated only when its reachable states and actions have a native ArkUI equivalent.

## 4. UI rewrite phases

### Phase U0 — UI inventory and behavioral specification

**Output:** `docs/harmony/UI_INVENTORY.md`

- Enumerate every SwiftUI screen, sheet, full-screen cover, alert, confirmation, menu and navigation destination.
- Record entry points and exit actions.
- Record all user-visible states: loading, empty, active, inactive, expired, error, offline and permission-required.
- Record all buttons/actions and their side effects.
- Identify reusable components and design tokens.
- Mark Apple-only behavior (StoreKit, Apple sign-in, App Review, iOS NetworkExtension presentation) so it is not copied into Harmony UI.

**Gate:** no unknown user-facing SwiftUI surface remains.

### Phase U1 — ArkUI design system

**Output:** `harmony/entry/src/main/ets/ui/`

Create a single Harmony design system:

- color tokens
- typography tokens
- spacing/grid
- corner radii
- borders/elevation
- icons and flag assets
- button variants
- cards/list rows
- badges/status pills
- dialogs/sheets
- loading/error/empty states
- accessibility helpers
- responsive phone/tablet metrics

The visual language should retain VPN Direct's existing dark, restrained product identity while using native HarmonyOS composition and interaction conventions.

**Gate:** screens do not contain arbitrary duplicated style constants.

### Phase U2 — Application shell and navigation

Build:

- application root
- tab/navigation model
- route definitions
- deep-link-safe navigation boundary
- modal/sheet presentation layer
- global toast/error presentation
- lifecycle-aware state restoration

**Gate:** every top-level product surface can be reached without placeholder navigation.

### Phase U3 — Home / VPN control

Implement the highest-risk screen first because it is coupled to the real VPN lifecycle:

- disconnected
- requesting trust/permission
- connecting
- connected
- disconnecting
- connection failed
- Core unavailable
- no usable server
- selected server presentation
- server switching

The UI must observe the Harmony VPN service instead of assuming that `startVpnExtensionAbility()` means the tunnel is already usable.

**Gate:** UI state is consistent with real `VpnExtensionAbility` + Core state on device.

### Phase U4 — Locations and server selection

Implement the location catalog and picker as shared ArkUI components:

- location list
- search
- flag assets
- server metadata
- ping/status
- auto location
- selected location
- unavailable state

**Gate:** Home and Locations use the same source of truth and selection model.

### Phase U5 — Plans / service / management

Rebuild:

- plans
- tariff period selector
- constructor
- service status
- management
- renewal
- imported/third-party subscription flows
- add/import menus

Payment implementation is a separate platform service concern. The UI must not embed Apple-only StoreKit concepts into Harmony.

**Gate:** all service states have deterministic UI and error handling.

### Phase U6 — Account / authentication / balance

Rebuild:

- login
- logout
- account switching
- account page
- account utilities
- balance
- transaction list
- top-up flow
- authentication loading/error/empty states

Provider-specific authentication mechanisms must be isolated behind a Harmony auth service.

**Gate:** account UI works without exposing backend implementation details to views.

### Phase U7 — Legal / privacy / settings

Rebuild:

- first-use VPN privacy disclosure
- privacy/legal center
- application information
- version/build information
- delete-account flow
- confirmations and failure states

The first-use disclosure is a product requirement and must block activation until the user explicitly accepts it.

**Gate:** fresh install → disclosure → accept/decline → VPN activation is deterministic.

### Phase U8 — Polish and HarmonyOS adaptation

- phone/tablet layouts
- portrait/landscape where supported
- large font/accessibility checks
- touch target checks
- keyboard/search behavior
- dark/light behavior if product design permits
- system bars and safe areas
- background/foreground lifecycle
- animation performance
- haptic/tactile equivalents where supported by HarmonyOS
- localization readiness

**Gate:** no iOS-specific visual assumptions remain.

### Phase U9 — Device validation

Validate on physical HarmonyOS NEXT hardware:

- first launch
- first VPN trust prompt
- connect/disconnect
- app background/foreground
- screen lock/unlock
- server switching
- network changes
- failed Core start
- Core stop during lifecycle transitions
- account flows
- every modal/alert
- phone and tablet layouts

**Gate:** no release candidate without real-device validation.

## 5. Screen/component migration matrix

| Surface | ArkTS target | Priority | Depends on |
|---|---|---:|---|
| App shell | `AppShell` | P0 | navigation/state |
| Home | `HomePage` | P0 | VPN session, server |
| Connect control | `VpnConnectControl` | P0 | VPN state |
| Server picker | `ServerPickerPage` / sheet | P0 | locations |
| Locations | `LocationsPage` | P1 | location repository |
| Plans | `PlansPage` | P1 | service repository |
| Plan constructor | `PlanConstructorPage` | P1 | plans/checkout |
| Management | `ManagementPage` | P1 | subscriptions |
| Account | `AccountPage` | P1 | auth |
| Authentication | `AuthPage` | P1 | auth service |
| Balance | `BalancePage` | P2 | balance service |
| Top-up | `BalanceTopUpPage` | P2 | balance/checkout |
| Transactions | `TransactionsPage` | P2 | balance service |
| Legal center | `LegalPage` | P1 | legal links |
| Privacy disclosure | `PrivacyDisclosurePage` | P0 | persisted consent |
| Delete account | `DeleteAccountPage` / dialog | P1 | account service |
| Subscription import | `SubscriptionImportPage` | P1 | import service |
| Advanced/utility views | `Utility*` / `Advanced*` | P2 | feature contracts |

Names are implementation targets, not a promise that every iOS type will be copied literally.

## 6. State model

The UI must use explicit state machines rather than scattered booleans.

### VPN

```text
idle
 ↓
privacyRequired → ready
 ↓
requestingPermission
 ↓
connecting
 ↓
connected
 ↓
disconnecting
 ↓
idle

Any active state → failed(reason)
```

### Data loading

Every repository-backed screen should model:

```text
idle → loading → loaded(data)
                 ↘ empty
                 ↘ failed(error)
```

### Account

```text
unknown → loading → signedOut
                  ↘ signedIn(account)
                  ↘ failed(error)
```

## 7. Repository structure

```text
harmony/entry/src/main/ets/
├── app/
│   ├── AppShell.ets
│   ├── AppState.ets
│   └── routes.ets
├── pages/
│   ├── HomePage.ets
│   ├── LocationsPage.ets
│   ├── PlansPage.ets
│   ├── ManagementPage.ets
│   ├── AccountPage.ets
│   ├── AuthPage.ets
│   ├── BalancePage.ets
│   ├── LegalPage.ets
│   └── PrivacyDisclosurePage.ets
├── components/
│   ├── VpnConnectControl.ets
│   ├── ServerRow.ets
│   ├── LocationRow.ets
│   ├── PlanCard.ets
│   ├── StatusBadge.ets
│   └── ...
├── ui/
│   ├── Theme.ets
│   ├── Typography.ets
│   ├── Spacing.ets
│   ├── Controls.ets
│   └── States.ets
├── state/
├── services/
└── vpn/
```

## 8. Definition of done

The Harmony UI rewrite is complete only when:

- every reachable iOS product flow has an ArkUI equivalent or a documented Harmony-specific replacement;
- every screen has loading/empty/error/permission states where applicable;
- no SwiftUI code is reused at runtime;
- no WebView is used as a UI shortcut;
- UI is driven by explicit presentation state;
- VPN state is sourced from the real Harmony VPN/Core lifecycle;
- first-use privacy disclosure is enforced;
- phone and tablet layouts are validated;
- accessibility/touch targets are reviewed;
- all navigation, sheets, dialogs and destructive confirmations are tested;
- Core/backend boundaries remain outside the visual layer;
- a real-device test pass is recorded before release.

## 9. Work order after this plan

1. Finish the SwiftUI UI inventory and behavioral map.
2. Create the ArkUI design system and application shell.
3. Replace the current temporary `Index.ets` demo UI with the real Home architecture.
4. Implement the real VPN state observer/controller boundary.
5. Build Locations + Server Picker.
6. Build Plans + Management.
7. Build Account + Auth + Balance.
8. Build Legal + Privacy Disclosure + Delete Account.
9. Migrate remaining utility/advanced/import flows.
10. Polish, test, and validate on physical HarmonyOS NEXT devices.

This plan deliberately keeps the Core/networking migration and UI migration as separate workstreams that meet at a narrow service boundary.
