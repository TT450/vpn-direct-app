# Native core build plan

## Preferred data plane

`HarmonyOS VpnExtensionAbility -> TUN fd -> tun2socks -> local SOCKS/mixed inbound -> VPNDirectCore/sing-box outbound`

This is based on the currently documented and device-tested pattern in Hey. The TUN adapter is a separate native library because the HarmonyOS VPN extension owns the TUN descriptor while sing-box is exposed through a native shared-library ABI.

## sing-box

VPN Direct currently pins its own core to `VPNDirectCore 0.1.0` and sing-box `v1.14.0-lx.35`. The HarmonyOS build should preserve VPN Direct's core semantics rather than silently switching to an unrelated upstream version. The initial spike should answer whether the existing Go overlays can compile for HarmonyOS with the OpenHarmony Go toolchain and whether any iOS-only assumptions exist.

## First device spike

1. Build a minimal HarmonyOS HAP with `VpnExtensionAbility`.
2. Create a TUN interface and verify IPv4/IPv6 route installation.
3. Build `tun2socks` as `arm64` HarmonyOS native code.
4. Expose a tiny C ABI for VPNDirectCore: start(config, tunFd), stop(), version().
5. Run a single VLESS/TLS/Reality configuration through the existing server.
6. Verify real TCP, UDP, DNS, disconnect, Wi-Fi/cellular transition, and lock-screen behavior on a physical Huawei device.

Do not claim production compatibility until those checks pass.