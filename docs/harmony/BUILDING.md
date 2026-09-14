# HarmonyOS NEXT Build Guide

## Toolchain

Development requires a HarmonyOS NEXT development environment with **DevEco Studio**, the matching HarmonyOS SDK/API level, and the native toolchain required by the selected Core build.

The repository does not commit signing certificates, profiles, private keys or AppGallery credentials.

## Project

Open the `harmony/` project in DevEco Studio.

Expected application structure:

```text
harmony/
├── AppScope/
│   └── app.json5
└── entry/
    ├── src/main/module.json5
    ├── src/main/ets/
    │   └── vpn/
    └── src/main/cpp/
```

## Native Core

The HarmonyOS target must produce an ARM64 native library implementing the public bridge:

```text
vpndirect_harmony_start(int tun_fd, const char* profile_json)
vpndirect_harmony_stop()
```

The library must be built from the pinned VPN Direct Core source. Do not substitute a different sing-box version merely because another HarmonyOS project embeds it.

Authoritative pins are stored in [`../../core/VERSION`](../../core/VERSION): VPN Direct Core `0.1.0`, sing-box-lx `v1.14.0-lx.35`, upstream `1.14.0`, Go `1.26.6`.

## Packaging

The resulting native library is packaged into the signed HAP. The application extension and native module must use the ABI expected by the HarmonyOS device target.

Do not package:

- Apple `.xcframework` files;
- iOS provisioning profiles;
- Apple entitlements;
- private backend configuration;
- production credentials.

## Validation order

```text
1. ArkTS compile
2. Native ARM64 compile
3. HAP packaging
4. Install on a real HarmonyOS device
5. Grant VPN authorization
6. Create TUN
7. Start VPN Direct Core
8. Validate TCP + UDP
9. Validate DNS + IPv4 + IPv6
10. Validate reconnect / stop / restart
```

See [`DEVICE_QUALIFICATION.md`](DEVICE_QUALIFICATION.md) for the acceptance matrix.

## Important limitation

The repository can contain the complete source/build seam, but a successful source commit must not be described as a compiled or device-tested HarmonyOS release. DevEco and physical-device evidence are required before release claims are made.
