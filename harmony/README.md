# VPN Direct — HarmonyOS NEXT

This directory is the HarmonyOS NEXT platform implementation of VPN Direct. It is **not** an Apple port and it does not reuse Apple `NetworkExtension`, StoreKit, App Store or TestFlight metadata.

## Runtime boundary

```text
ArkUI / application process
        │
        ├── backend adapter → normalized DirectVpnProfile
        │                         │
        │                         └── full sing-box JSON
        ▼
VpnDirectVpnExtension (VpnExtensionAbility)
        │
        ├── HarmonyOS VpnConnection
        ├── IPv4/IPv6 TUN + default routes
        ├── protectProcessNet()
        └── N-API bridge
                │
                ▼
        VPN Direct Core (ARM64 .so)
                │
                ▼
        sing-box-lx v1.14.0-lx.35
```

The native core is application code and must be packaged and signed with the HAP. A remote subscription/config may supply **data only**; it must never download or replace `.so` files or other executable code.

## Core contract

`DirectVpnProfileProvider` is the backend seam. The backend adapter supplies a normalized profile containing:

- server identifier;
- IPv4/IPv6 tunnel addresses;
- DNS and MTU;
- a complete, validated sing-box JSON configuration.

The UI never builds a fake VPN configuration and the extension never treats `address/dns/mtu` as a substitute for a real sing-box config.

The extension creates the system TUN, protects the extension process before outbound sockets are opened, and passes the TUN fd plus the profile envelope to the native core. The core calls `libbox.Setup`, validates the configuration with `libbox.CheckConfig`, starts `libbox.BoxService`, and publishes a real runtime state file.

Runtime states are:

```text
Disconnected → Connecting → Connected → Disconnecting → Disconnected
                                  └──────────────→ Failed
```

`Connected` is only published after `BoxService.Start()` succeeds. A two-second heartbeat prevents a dead extension/core from leaving a stale `Connected` state in the UI.

## Reconnect and server switching

Server selection is centralized in `VpnServerSelection`. When the selected server changes while the tunnel is active, the app performs:

```text
Connected
   ↓
stop extension
   ↓
wait for Disconnected
   ↓
fetch target profile
   ↓
start extension
   ↓
Connected
```

This avoids pretending that changing a UI label changes the active outbound.

## Reproducible ARM64 core build

The checked-in source does **not** contain the generated `libvpndirect_engine.so`. It is intentionally ignored. Build it on a DevEco/OpenHarmony ARM64 host:

```bash
bash scripts/bootstrap_core.sh
bash scripts/build_harmony_core.sh
```

The script requires DevEco/OpenHarmony native ARM64 clang, the pinned OpenHarmony Go toolchain and `core/sing-box` at the revision pinned in `core/VERSION`.

The result is:

```text
harmony/entry/src/main/cpp/prebuilt/arm64-v8a/libvpndirect_engine.so
```

The script checks the ARM64 ELF header and both exported symbols `vpndirect_harmony_start` and `vpndirect_harmony_stop`.

## HAP release gate

After the core exists:

```bash
bash harmony/scripts/release_gate.sh
```

For a configured DevEco/Hvigor host:

```bash
RUN_HVIGOR_BUILD=1 bash harmony/scripts/release_gate.sh
```

CMake deliberately fails if the engine is absent and copies the validated engine beside `libvpndirect_core.so` so the final HAP contains both native artifacts.

A self-hosted GitHub Actions workflow is provided at `.github/workflows/harmony-release.yml`. It expects a runner labelled `harmonyos` with DevEco/OpenHarmony SDK, the pinned OpenHarmony Go toolchain and Hvigor installed.

## Production status

The repository now contains the production runtime path, state lifecycle, profile contract, server switching, core validation, native packaging guard and release gate. **A compiled HAP, compiled ARM64 engine and physical-device traffic qualification remain external build/device gates until those artifacts are actually produced and tested on HarmonyOS hardware.**
