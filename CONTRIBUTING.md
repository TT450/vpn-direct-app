# Contributing to VPN Direct

Thanks for helping improve the open-source VPN Direct platform and Core.

This branch is dedicated to **HarmonyOS NEXT**. Apple-specific runtime work belongs to the Apple platform branch.

## Before you start

1. Read [`docs/harmony/ARCHITECTURE.md`](docs/harmony/ARCHITECTURE.md) for the platform boundary.
2. Read [`docs/core/ARCHITECTURE.md`](docs/core/ARCHITECTURE.md) before changing Core-facing code.
3. Do **not** commit secrets: signing keys, certificates, provisioning material, real server credentials, private keys or production subscription URLs.
4. Do **not** commit generated native binaries unless the project explicitly requires a release artifact.
5. Do **not** claim a protocol or device path is `tested` without interoperability and real-device evidence.

## HarmonyOS development

Use DevEco Studio with the HarmonyOS NEXT SDK and the native toolchain required by the pinned Core.

```text
ArkUI / ArkTS
    ↓
VpnExtensionAbility
    ↓
HarmonyOS TUN
    ↓
N-API
    ↓
VPN Direct Core
```

The platform adapter should remain thin. Protocol behavior belongs in the shared Core rather than being reimplemented in ArkTS.

## Pull requests

- Prefer small, reviewable changes.
- Include a short **why** in the description.
- Update HarmonyOS documentation when the platform architecture changes.
- Update `docs/core/PROTOCOL_MATRIX.md` and `core/protocol-matrix.json` when Core protocol status changes.
- Keep capability checks fail-closed.
- Add or update regression fixtures for parser/builder changes.
- Record real-device evidence before promoting a feature to `tested`.

## Security boundary

Remote configuration is data. It must never become a mechanism for downloading or replacing executable native code.

Never commit production credentials, private endpoints, signing material or real subscription URLs.

## License

By contributing, you agree that your contributions are licensed under the **GNU GPL v3** (or later), consistent with this repository and its upstream components.
