# VPN Direct Core architecture

HarmonyOS branch: **`harmony-os-app`** · Core pin: [`core/VERSION`](../../core/VERSION)

## Strategy

Upstream **sing-box** remains the foundation. VPN Direct Core is a **thin fork** starting from `sing-box-lx`; custom features stay isolated behind overlays/build tags so the Core can be rebuilt for more than one mobile platform without silently changing protocol behavior.

```text
SagerNet/sing-box
        │
        ▼
core/sing-box (sing-box-lx + VPN Direct overlays)
        │
        ├───────────────┐
        ▼               ▼
Apple native Core   HarmonyOS native Core
Libbox / Darwin     signed ARM64 .so
        │               │
NetworkExtension   VpnExtensionAbility
        │               │
        └────── VPN Direct platform APIs ──────┘
```

## HarmonyOS platform adapter

The HarmonyOS adapter is deliberately a thin platform layer. HarmonyOS owns creation/destruction of the system TUN interface through `VpnExtensionAbility` / `vpnExtension.VpnConnection`; VPN Direct Core owns protocol/session processing.

```text
ArkUI / application process
        │
        ▼
VpnDirectVpnExtension
        │
        ├── VpnConnection.create()
        │        └── TUN fd
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

The adapter follows the proven HarmonyOS pattern used by Hey (ArkTS + VPN Extension + native bridge + TUN data plane) while taking lifecycle/reliability practices from other real-device HarmonyOS VPN implementations. The project does not copy their Xray runtime or their older sing-box pins.

## Subscription / import pipeline

The normalized data model remains platform-neutral:

```text
raw bytes / file / paste / QR / URL
  → VPNDirectContentDetector
  → format adapters / VPNDirectParserRegistry
  → NormalizedSubscription → NormalizedLocation[] → NormalizedNode[]
  → UniversalOutboundBuilder (+ capability gates)
  → SingBoxGraphBuilder
  → platform-native Core ABI
```

The HarmonyOS adapter receives configuration **data**. It never receives executable code, native libraries, credentials or private backend endpoints from a subscription.

## Capability Registry

The Core must report capabilities from the actual linked native binary. Platform adapters must not assume that the Apple Libbox capability set is available on HarmonyOS.

- Go capability definitions remain under `core/overlays/`.
- Apple capability exposure remains under `Library/Shared/VPNDirectCoreCapabilities.swift`.
- HarmonyOS will expose the equivalent capability JSON/ABI through the native bridge.
- Unsupported features must fail closed; no silent transport substitution.

## Platform metadata

Apple metadata stays in the existing Apple targets. HarmonyOS metadata is separate:

| Concern | HarmonyOS |
|---|---|
| App metadata | `harmony/AppScope/app.json5` |
| Module metadata | `harmony/entry/src/main/module.json5` |
| VPN extension | `harmony/entry/src/main/ets/vpn/VpnDirectVpnExtension.ets` |
| ArkTS/native bridge | `HarmonyCoreBridge.ets` + `napi_init.cpp` |
| Native Core | signed ARM64 `.so` built from the pinned Core |
| Distribution | AppGallery Connect |

## Build rule

The Apple `Libbox.xcframework` is not reusable on HarmonyOS. HarmonyOS requires a separately compiled native ARM64 library and a HarmonyOS-compatible Go/NDK toolchain. The Core version and sing-box revision remain pinned to [`core/VERSION`](../../core/VERSION).

## Status vocabulary

`parser+runtime` ≠ `tested`. HarmonyOS production status requires real-device evidence for VPN authorization, TUN creation, IPv4/IPv6 TCP and UDP, DNS, real egress, reconnect, Wi-Fi/cellular switching, background/lock-screen stability and clean network restoration after disconnect.

## Update / rebase

```text
cd core/sing-box
git fetch upstream
git rebase upstream/<tag>   # then re-apply // lx seams if needed
```

See [`BUILDING.md`](BUILDING.md), [`DONORS.md`](DONORS.md) and [`../../harmony/README.md`](../../harmony/README.md).
