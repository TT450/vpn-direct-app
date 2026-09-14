# VPN Direct — HarmonyOS VPN Adapter

This directory is the HarmonyOS NEXT platform layer for VPN Direct.

## Architecture

```text
ArkUI / ArkTS app
        |
        v
VpnExtensionAbility
        |
        v
HarmonyOS TUN
        |
        v
tun2socks adapter
        |
        v
VPNDirectCore / sing-box
```

The first implementation follows the proven HarmonyOS pattern used by the open-source [Hey](https://github.com/popsiclelmlm/Hey) project: the VPN extension owns the HarmonyOS TUN lifecycle, while a native tun2socks layer forwards TUN traffic into the core's local SOCKS/mixed inbound. Hey documents this data path and also provides a working HarmonyOS sing-box build path. The implementation should be adapted to VPN Direct rather than copied wholesale.

## Why this approach

- Keeps the VPN engine independent from HarmonyOS APIs.
- Avoids coupling ArkTS UI to sing-box internals.
- Lets VPN Direct preserve its existing config/subscription model.
- Gives us a clean platform boundary comparable to iOS `NetworkExtension` and Android `VpnService`.

## Upstream references

- Huawei `VpnExtensionAbility` / `VpnExtensionContext`: https://developer.huawei.com/consumer/en/doc/harmonyos-references-V13/js-apis-inner-application-vpnextensioncontext-V13
- Hey HarmonyOS VPN/tun2socks: https://github.com/popsiclelmlm/Hey
- HarmonyOS sing-box build notes in Hey: https://github.com/popsiclelmlm/Hey/blob/main/docs/building-native-cores.md

## Important

Do not vendor third-party source into this branch until license and compatibility review is complete. The current branch starts with architecture and integration scaffolding only. The VPN data plane must be validated on a real HarmonyOS device before claiming production support.