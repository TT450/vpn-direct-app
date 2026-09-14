# HarmonyOS NEXT UI — Pixel Parity Contract

HarmonyOS NEXT is not a redesign of VPN Direct. The Harmony client must reproduce the existing iOS DirectUI visual language and interaction behavior as closely as the platform allows.

The iOS implementation is the visual source of truth. ArkTS/ArkUI is the implementation technology, not a reason to invent a second design system.

## Non-negotiable rules

- Same screens and navigation hierarchy.
- Same information architecture and copy.
- Same component geometry, spacing, alignment, hierarchy and density.
- Same colors, opacity values, typography and visual weight.
- Same icons, server badges and flag treatment.
- Same empty, loading, success, failure and disabled states.
- Same sheets, alerts, confirmations and destructive-action flows.
- Same connection states and status presentation.
- Same animations and timing where ArkUI supports equivalent behavior.
- Same sounds and haptic feedback semantics, mapped to the closest HarmonyOS native mechanism without changing when feedback occurs.
- No additional tabs, cards, settings, badges, labels, controls or platform-branded visual elements.
- No dark-theme reinterpretation, new accent color or Harmony-specific visual language.

## iOS design tokens

The current SwiftUI DirectUI design system defines:

| Token | Value |
|---|---|
| Paper | RGB 0.93 / 0.94 / 0.91 |
| Ink | RGB 0.08 / 0.09 / 0.08 |
| Panel | RGB 0.19 / 0.21 / 0.18 |
| Muted | RGB 0.48 / 0.50 / 0.46 |
| Line | black at 14% opacity |
| Acid | RGB 0.66 / 0.94 / 0.41 |
| Green | RGB 0.18 / 0.55 / 0.31 |
| Danger | RGB 0.82 / 0.24 / 0.20 |
| Page top | 24pt |
| Micro label | 9pt, semibold, monospaced |
| Page title | 22pt, semibold |
| Page subtitle | 13pt |

These values come from `ApplicationLibrary/Views/DirectUI/DesignSystem.swift`. They are the source of truth and replace the temporary Harmony-specific dark palette.

## Migration method

For every iOS screen:

1. Identify the exact SwiftUI view and all child components.
2. Record exact geometry and visual tokens.
3. Record every interaction and state transition.
4. Record every animation, sound and haptic event.
5. Rebuild the same composition in ArkUI.
6. Compare screenshots at the same logical viewport sizes.
7. Compare connected/disconnected/loading/error states separately.
8. Compare interaction feedback separately.
9. Do not mark the screen complete until parity is verified.

## Platform mapping

Apple-only implementation details are replaced, but user-visible behavior is preserved:

- SwiftUI → ArkUI.
- NetworkExtension → HarmonyOS VPN extension lifecycle.
- StoreKit UI → the Harmony service flow appropriate to the distribution channel.
- UIKit haptics → HarmonyOS haptic capability with identical event semantics.
- iOS sound implementation → HarmonyOS audio implementation with the same event timing and assets where package constraints permit.
- iOS sheets/navigation → ArkUI equivalent presentation with the same hierarchy and visual composition.

The platform layer may differ internally. The product UI must not.

## Completion gate

A screen is complete only when visual comparison passes, all reachable states exist, all actions work, all feedback events are mapped, no unrequested Harmony-specific UI exists, phone layout is verified, tablet layout is verified where applicable, and real-device rendering has been checked.
