# HarmonyOS NEXT UI inventory baseline

This document is the migration checklist for the complete SwiftUI → ArkTS rewrite. It is intentionally kept separate from the implementation so a screen cannot be considered migrated merely because an ArkUI page exists.

## Primary surfaces identified in the current DirectUI implementation

| Reference SwiftUI surface | Harmony target | State coverage required | Status |
|---|---|---|---|
| `VPNHomeView` | `HomePage` | disconnected / permission / connecting / connected / disconnecting / failed | planned |
| `DirectHomePage` | Home content | selected server / import / service state / errors | planned |
| `DirectProfilePage` | `AccountPage` | signed-in / signed-out / loading / error | planned |
| `DirectAccountView` | `AuthPage` / account sheet | login / logout / switch / error | planned |
| `DirectServersPage` | `LocationsPage` | search / list / empty / unavailable | planned |
| `DirectServerPickerView` | `ServerPickerPage` | auto / selected / ping / unavailable | planned |
| `DirectLocationsCatalog` | `LocationsPage` data layer | location metadata / flags | planned |
| `DirectPlansView` | `PlansPage` | periods / service state / errors | planned |
| `DirectConstructorView` | `PlanConstructorPage` | period / price / checkout state | planned |
| `DirectManagementPage` | `ManagementPage` | active / expired / imported / renewal | planned |
| `DirectBalanceAccountView` | `BalancePage` | loading / balance / error | planned |
| `DirectBalanceTopUpView` | `BalanceTopUpPage` | amount / checkout / success / error | planned |
| `DirectBalanceFlow` | balance service/state | transaction state machine | planned |
| `DirectLegalInformationView` | `LegalPage` | links / version / delete account | planned |
| `DirectPrivacyDisclosureView` | `PrivacyDisclosurePage` | first-use accept / decline | planned |
| `DirectAccessViews` | access/subscription flows | loading / active / unavailable / error | planned |
| `DirectAdvancedViews` | advanced/utility pages | feature-specific states | planned |
| `DirectAccountUtilityViews` | account utilities | loading / action / error | planned |
| `AutoSubscriptionImporter` | `SubscriptionImportPage` | parsing / validation / success / error | planned |
| `AppLockModifier` | Harmony app-lock service/UI | locked / unlocked | platform-specific review |
| `DialView` | reusable connection visual | idle / active / animated | planned |
| `DesignSystem` | `harmony/.../ui/` | tokens/components | in progress |

## Required modal/secondary-state audit

The implementation pass must explicitly enumerate every:

- sheet
- full-screen presentation
- alert
- confirmation dialog
- context/menu action
- navigation destination
- empty state
- loading state
- error state
- permission/trust state
- destructive action confirmation

## Platform-only behavior that must NOT be copied literally

- StoreKit / Apple IAP UI
- Apple-specific sign-in controls
- NetworkExtension UI assumptions
- iOS-only system settings navigation
- iOS-specific haptic APIs
- SwiftUI navigation implementation

These behaviors must be mapped to HarmonyOS services and native ArkUI interaction patterns.

## Migration gate

A surface moves from `planned` to `implemented` only after:

1. ArkTS/ArkUI screen exists.
2. All reachable states are represented.
3. Actions are connected to the presentation/service layer.
4. Loading/empty/error states are handled.
5. Phone layout is checked.
6. Tablet layout is checked where supported.
7. Accessibility/touch targets are checked.
8. Real-device behavior is verified for platform-dependent flows.
