# VPN Direct Core — HarmonyOS ABI

The HarmonyOS platform adapter exposes the smallest possible native boundary:

```cpp
extern "C" int vpndirect_harmony_start(int tun_fd, const char* profile_json);
extern "C" int vpndirect_harmony_stop();
```

## Contract

### `vpndirect_harmony_start`

- `tun_fd` is the file descriptor returned by HarmonyOS `VpnConnection.create()`.
- `profile_json` is configuration data only.
- The function returns `0` on successful Core startup.
- A non-zero return means the Core did not start and the adapter must not report an active VPN.
- The call must not download or dynamically load executable code.

### `vpndirect_harmony_stop`

- Stops the active Core session.
- Returns `0` when stopped or already stopped.
- A non-zero result is surfaced to the platform layer.
- Core shutdown must complete before the platform releases the VPN interface.

## Threading

The platform adapter serializes lifecycle calls. The final Core implementation must not block the ArkTS/UI thread while running the VPN data plane.

## Versioning

This ABI belongs to VPN Direct Core `0.1.0`. Changes require a Core version review and corresponding adapter update.

## Current status

The public ABI seam and N-API adapter exist. The actual ARM64 HarmonyOS implementation is **not yet linked**. Until that artifact exists, native start returns `-1000` (`CORE_NOT_LINKED`) and the app must remain disconnected.
