# Security Policy

## Supported scope

This branch covers the **VPN Direct HarmonyOS NEXT platform layer and shared VPN Direct Core**.

Security fixes are accepted against the active development branch for the affected component.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for an unfixed security problem.

Use a private security advisory on GitHub if enabled, or contact the maintainers through a private channel associated with the VPN Direct / TheTochka project.

Include:

- affected component (ArkTS UI, `VpnExtensionAbility`, N-API bridge, native Core, parser/builder);
- steps to reproduce;
- impact assessment;
- device and HarmonyOS/API version when relevant;
- Core revision and build configuration when relevant;
- whether a fix or mitigation is already proposed.

## Security boundaries

- Subscription/configuration input is untrusted data.
- Remote configuration must not download or replace executable native code.
- Native libraries must be packaged and signed with the application.
- Signing credentials and private backend material never belong in this repository.
- Third-party VPN server misconfiguration is out of scope unless it exposes a vulnerability in VPN Direct itself.

## Device reports

For VPN runtime issues, include the HarmonyOS device model, OS/API level, application version, Core revision and relevant logs with secrets redacted.
