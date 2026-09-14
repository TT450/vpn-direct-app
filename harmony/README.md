# VPN Direct — HarmonyOS NEXT

This directory is the HarmonyOS NEXT platform implementation of VPN Direct. It is **not** an Apple port and it does not reuse Apple `NetworkExtension`, StoreKit, App Store or TestFlight metadata.

## Adapter decision

The platform adapter combines two proven open-source implementation patterns:

1. **Hey** (`popsiclelmlm/Hey`) — selected as the primary architecture reference because it uses a native `VpnExtensionAbility`, an N-API boundary and a TUN-to-native-core data path. Its documented path is `HarmonyOS TUN fd → tun2socks/native data plane → local core inbound → protocol core`.
2. **AI-Scarlett/HarmonyOS_VPN** — selected as the reliability reference for real-device VPN lifecycle, dual-stack routing, process protection, and the separation of UI state from the VPN extension process.

We intentionally do **not** copy their Xray runtime or their sing-box pin. VPN Direct keeps its own Core pin from `core/VERSION`: `sing-box-lx v1.14.0-lx.35`, with VPN Direct overlays/capabilities.

## Runtime boundary

```text
ArkUI / application process
        │
        ├── subscription/config data
        │
        ▼
VpnDirectVpnExtension (VpnExtensionAbility)
        │
        ├── HarmonyOS VpnConnection
        ├── system TUN fd
        └── N-API bridge
                │
                ▼
        VPN Direct Core (native, signed into HAP)
                │
                ▼
        sing-box-lx v1.14.0-lx.35
```

The native core is application code and must be packaged and signed with the HAP. A remote subscription/config may supply **data only**; it must never download or replace `.so` files or other executable code.

## Apple → HarmonyOS metadata conversion

HarmonyOS uses its own application metadata and lifecycle. Apple-only identifiers are not reused as HarmonyOS runtime identifiers.

| Apple | HarmonyOS |
|---|---|
| `NetworkExtension` / `PacketTunnelProvider` | `VpnExtensionAbility` / `VpnConnection` |
| `Info.plist` | `AppScope/app.json5` + `entry/src/main/module.json5` |
| Bundle ID `com.vpndirect.vpndirectapp` | HarmonyOS bundle namespace starts from `com.vpndirect.vpndirectapp` but is declared in Harmony metadata |
| App Store / TestFlight | AppGallery Connect |
| StoreKit / RevenueCat | Server-side entitlement state; AppGallery/IAP integration is a separate layer if monetisation is enabled |
| Apple VPN permission | HarmonyOS system VPN authorization |
| App Group | HarmonyOS application-private storage / IPC mechanisms |
| SwiftUI | ArkUI / ArkTS |
| Libbox.xcframework | signed ARM64 HarmonyOS native library |

## Current status

The platform boundary and metadata are now present on `harmony-os-app`. The native core ABI is deliberately a build seam (`vpndirect_harmony_start/stop`) because the Apple `Libbox.xcframework` cannot be reused on HarmonyOS.

The remaining external gate is a DevEco Studio/DevEco CLI build and real-device validation. This repository change does not claim that a HarmonyOS HAP or native `.so` has already been compiled here.
