# HarmonyOS adapter rules

- Keep HarmonyOS-specific code under `harmony/`.
- Do not copy iOS `NetworkExtension` types into portable core APIs.
- Do not fork or duplicate VPNDirectCore logic in ArkTS.
- The native core ABI must remain small and versioned.
- TUN lifecycle belongs to `VpnExtensionAbility`; core lifecycle belongs to the native bridge.
- Config data may cross the boundary as validated JSON; executable code must never be delivered remotely.
- Do not add secrets, backend hosts, private provisioning files, or private backend clients to this public repository.
- Before adding third-party code, record its source and license and confirm GPL/LGPL/MIT compatibility with VPN Direct distribution.
- A real-device HarmonyOS test is required before treating the adapter as production-ready.
