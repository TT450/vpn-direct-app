# VPN Direct — HarmonyOS NEXT

VPN Direct is a native HarmonyOS NEXT VPN client using **ArkTS/ArkUI**, **VpnExtensionAbility** and the project’s own reproducible **VPN Direct Core** based on the pinned sing-box-lx source.

> This `harmony-os-app` branch is the HarmonyOS platform branch. Apple-only runtime details such as NetworkExtension, PacketTunnelProvider, StoreKit, App Store and TestFlight are intentionally not used here.

## Architecture

```text
ArkUI / VPN Direct UI
        │
        ▼
VPN service state / subscription data
        │
        ▼
VpnDirectVpnExtension
(VpnExtensionAbility)
        │
        ├── HarmonyOS VpnConnection
        │       └── system TUN fd
        │
        ▼
N-API native bridge
        │
        ▼
VPN Direct Core
        │
        ▼
sing-box-lx v1.14.0-lx.35
```

HarmonyOS supplies the virtual network interface and VPN lifecycle; VPN Direct implements the tunnel internals and protocol processing. Huawei’s VPN API explicitly follows this model: the application creates the virtual network and implements the tunnel internals itself. citeturn0search4

## Adapter choice

The HarmonyOS adapter is based on a comparison of real open-source implementations:

- **Hey** — primary architecture reference. It uses ArkTS, Stage model, `VpnExtensionAbility`, a native N-API bridge and a TUN-to-native-core data plane. Its documented path is `HarmonyOS VPN TUN fd → native TUN adapter → local core inbound → protocol core`. citeturn0search0
- **HarmonyOS_VPN** — reliability/reference implementation. It demonstrates real-device VPN lifecycle, dual-stack TUN routing, process protection, and a separation between UI state and the VPN extension process. Its embedded sing-box version is **not** used by VPN Direct because this project is pinned to `v1.14.0-lx.35`. citeturn0search2
- **ClashHM** — secondary reference for keeping the VPN runtime inside `VpnExtensionAbility` and using a native core without requiring a foreground process. citeturn0search5

**Decision:** use the `Hey`-style platform boundary and TUN/native bridge, with the stronger lifecycle/reliability rules demonstrated by `HarmonyOS_VPN`, while keeping **VPN Direct Core** and its existing protocol/build pins unchanged.

## Core pin

The HarmonyOS port uses the same project Core lineage instead of silently substituting another sing-box build:

- Core: `VPNDirectCore 0.1.0`
- sing-box source: `Leadaxe/sing-box-lx`
- revision: `v1.14.0-lx.35`
- upstream version: `1.14.0`
- Go: `go1.26.6`

These pins are authoritative in [`core/VERSION`](core/VERSION). fileciteturn631file0L2-L2

## HarmonyOS application metadata

| Apple concept | HarmonyOS implementation |
|---|---|
| `Info.plist` | `harmony/AppScope/app.json5` + `entry/src/main/module.json5` |
| SwiftUI | ArkUI / ArkTS |
| `NetworkExtension` | `VpnExtensionAbility` |
| `NEPacketTunnelProvider` | `VpnDirectVpnExtension` |
| `NETunnelProviderManager` | HarmonyOS `vpnExtension.VpnConnection` |
| `Libbox.xcframework` | signed ARM64 HarmonyOS native library |
| App Store / TestFlight | AppGallery Connect |
| StoreKit / RevenueCat | separate HarmonyOS monetisation layer; not part of the VPN adapter |
| Apple App Group | HarmonyOS private storage / IPC |

Huawei documents `VpnExtensionAbility` as the Stage-model extension used for third-party VPNs and `VpnConnection.create()` as the API that creates the VPN network and returns the virtual-interface file descriptor. citeturn0search1turn0search6

## Security boundary

The native core is executable application code and must be packaged into the signed HAP. Subscription/configuration data can describe a server or protocol, but it cannot download, replace or hot-swap `.so` files or other executable code.

No private backend endpoints, credentials, signing material or real subscription URLs belong in this public repository.

## Current HarmonyOS tree

```text
harmony/
├── AppScope/
│   └── app.json5
└── entry/
    ├── src/main/module.json5
    ├── src/main/ets/vpn/
    │   ├── VpnDirectVpnExtension.ets
    │   └── HarmonyCoreBridge.ets
    └── src/main/cpp/
        └── napi_init.cpp
```

## Build status

The platform adapter and HarmonyOS metadata are now on **`harmony-os-app`**. The remaining platform-specific work is the DevEco/NDK implementation of the `VPNDirectCore` native ABI, packaging the ARM64 library into the HAP, and real-device qualification.

This repository change does **not** claim that a HarmonyOS HAP or `.so` has been compiled in this environment.

## Existing Core architecture

The project’s Core remains intentionally thin and capability-driven: protocol parsing/building is separated from the native runtime, and unsupported features must fail closed rather than being silently converted. fileciteturn636file0L2-L2

## License

VPN Direct is distributed under the GNU General Public License v3 or later. See [`LICENSE`](LICENSE), [`NOTICE`](NOTICE) and [`docs/core/LICENSE_AUDIT.md`](docs/core/LICENSE_AUDIT.md).
