# HarmonyOS NEXT Architecture

## Scope

This document defines the native HarmonyOS NEXT platform layer for VPN Direct. The HarmonyOS adapter is intentionally separate from the Apple Network Extension implementation while reusing the project’s protocol, configuration and Core concepts.

## Runtime layers

```text
ArkUI / ArkTS application
        │
        │ control + configuration data
        ▼
VpnExtensionAbility
        │
        ├── VpnConnection
        │       └── HarmonyOS TUN fd
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

### Responsibilities

| Layer | Responsibility |
| --- | --- |
| ArkUI / ArkTS | UI, account/session state, profile selection and user actions |
| `VpnExtensionAbility` | System VPN lifecycle and TUN ownership |
| N-API | Small, explicit ArkTS ↔ native ABI boundary |
| VPN Direct Core | Configuration validation, capabilities and tunnel runtime |
| sing-box-lx | Protocol and transport implementation |

## Why this adapter

The platform boundary follows the strongest common pattern observed in mature HarmonyOS VPN projects: native `VpnExtensionAbility`, a system TUN descriptor, and a native bridge into the networking core. The data-plane design is compatible with the TUN/native-core approach used by Hey, while lifecycle and qualification rules follow the more conservative patterns demonstrated by HarmonyOS_VPN.

VPN Direct does not embed another project's runtime wholesale. In particular, the HarmonyOS implementation does not replace the project’s pinned Core with an unrelated sing-box release.

## Lifecycle

1. The application selects a valid VPN profile.
2. The VPN extension is created by HarmonyOS.
3. The extension creates/configures the system VPN interface.
4. HarmonyOS returns the virtual-interface file descriptor.
5. The native bridge starts the pinned VPN Direct Core against that descriptor.
6. Core owns protocol/session processing until stop or extension destruction.
7. Stop tears down Core first, then releases the VPN interface.

The extension must remain defensive: malformed profile data, duplicate starts and failed native initialization must not leave a partially running tunnel.

## Configuration boundary

Profile input is treated as untrusted data. The platform adapter may pass normalized configuration to Core, but it must not:

- download native libraries;
- load executable code from a subscription;
- accept private signing material;
- bypass Core capability checks;
- silently substitute an unsupported protocol.

## Native ABI

The current public ABI seam is intentionally small:

```text
vpndirect_harmony_start(tun_fd, profile_json) -> int
vpndirect_harmony_stop() -> int
```

The final implementation of these functions belongs to the HarmonyOS build of VPN Direct Core. They are not an invitation to duplicate the iOS Libbox implementation.

## Platform separation

| Apple | HarmonyOS NEXT |
| --- | --- |
| SwiftUI | ArkUI / ArkTS |
| `NETunnelProviderManager` | `VpnConnection` |
| `NEPacketTunnelProvider` | `VpnExtensionAbility` |
| Network Extension TUN | HarmonyOS VPN TUN |
| Libbox XCFramework | ARM64 native HarmonyOS library |
| App Group | HarmonyOS private storage / IPC |
| App Store / TestFlight | AppGallery Connect |

## Qualification gate

Source-level integration is not equivalent to device support. A protocol becomes `tested` for HarmonyOS only after the real-device checklist in [`DEVICE_QUALIFICATION.md`](DEVICE_QUALIFICATION.md) is satisfied.
