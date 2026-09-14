# Remaining SwiftUI → ArkUI migration

The HarmonyOS branch keeps the iOS DirectUI information architecture and visual language while replacing SwiftUI presentation/state with native ArkUI components.

## Destination coverage

| iOS destination / state | ArkUI implementation |
|---|---|
| server picker sheet | `DirectServerPickerFlow` |
| connection report sheet | `DirectConnectionReportFlow` |
| profiles sheet | `DirectProfilesFlow` |
| access choice | `DirectAccessFlow` |
| subscription detail | `DirectSubscriptionFlow` |
| premium plans | `DirectPlansFlow` |
| plan constructor | `DirectConstructorFlow` |
| payment method | `DirectPaymentFlow` |
| payment processing | `DirectFlow.PaymentProcessing` + `DirectStateFlow` |
| payment waiting | `DirectFlow.PaymentWaiting` + `DirectStateFlow` |
| payment cancelled | `DirectFlow.PaymentCancelled` + `DirectStateFlow` |
| payment error | `DirectFlow.PaymentError` + `DirectStateFlow` |
| payment success | `DirectFlow.PaymentSuccess` + `DirectStateFlow` |
| balance | `DirectBalanceFlow` |
| balance top-up | `DirectBalanceTopUpFlow` |
| account | `DirectAccountFlow` |
| devices | `DirectAccountFlow` |
| payment history | `DirectAccountFlow` |
| login / email / code | `DirectAuthFlow` |
| register / recovery | `DirectAuthFlow` |
| bot / phone / phone code | `DirectAuthFlow` |
| auth success | `DirectAuthFlow` |
| management | `DirectManagementFlow` + Management tab |
| security | `DirectSettingsFlow` |
| connection | `DirectSettingsFlow` |
| diagnostics | `DirectSettingsFlow` |
| activity | `DirectSettingsFlow` |
| system settings / warning | `DirectSettingsFlow` |
| application / core / tunnel / on-demand settings | `DirectSettingsFlow` |
| import file | `DirectImportFlow` |
| import config text | `DirectImportFlow` |
| legal | `DirectLegalFlow` |
| privacy | `DirectLegalFlow` |

## State model

`DirectFlow` is the presentation state for detail destinations. `FlowState` covers loading, waiting, error and success states without introducing platform-specific SwiftUI abstractions.

The flow host is deliberately isolated from the VPN engine. UI transitions do not create, mutate, or replace signed executable code or Network/VPN capabilities. The future production adapter must connect these actions to the existing HarmonyOS backend/Core service layer.

## Important implementation boundary

This is a UI/state migration, not a claim that every backend action is already wired. Payment, authentication, account, catalog, profile import and remote-service operations must be connected to the same product/backend contracts used by VPN Direct; private backend hosts, credentials and secrets are not copied into the public repository.

## Design rule

Do not redesign the product for HarmonyOS. Preserve the DirectUI hierarchy, spacing, micro-labels, paper/ink/acid palette, navigation semantics, loading/error states and haptic intent, implemented with native ArkUI/ArkTS primitives.
