# VPN Direct 1.0.11 (111) — Release Readiness Contract

Date: 2026-09-14

This document is the execution contract for the current production candidate. It deliberately separates code-completable gates from evidence that requires a physical iPhone / App Store Connect.

## Product contract

- Product: **VPN Direct**, native Apple VPN client.
- Current marketing version: **1.0.11**.
- Current TestFlight build: **111**.
- VPN datapath: Apple NetworkExtension / Packet Tunnel / Libbox.
- First-use VPN privacy disclosure is mandatory before the first Connect.
- Free/Premium access is **not a user-facing product mode** in the current submitted UX. Do not reintroduce Free/Premium navigation, banners, or access-choice copy.
- Provider subscriptions and the VPN connection itself remain separate concerns.
- No executable code is downloaded as remote configuration.
- No signing credentials, private keys, real subscription URLs, or backend secrets belong in this repository.

## Code-completable gates

- [x] NetworkExtension / PacketTunnel architecture remains the production path.
- [x] First-use privacy disclosure gate exists before Connect.
- [x] Account deletion entry point exists and fails closed when the private backend hook is absent.
- [x] Legal/privacy links are exposed from Profile.
- [x] App Store review prompt is delayed after successful Connect and rate-limited locally.
- [x] Subscription graph/parser production gates exist.
- [x] Libbox capability/ABI gates exist.
- [x] macOS CI compiles SFI/SFM/SFT unsigned targets.
- [ ] Remove remaining legacy **Free/Premium** wording from any active user-facing path. Internal compatibility identifiers may remain only when they are not surfaced to users and do not control the submitted navigation.
- [ ] Run the complete macOS CI pipeline against this release branch and resolve every compile/test failure rather than treating a partial workflow as release evidence.

## Device-only gates

These cannot be honestly completed from GitHub alone:

- interactive iOS VPN permission;
- first Connect through the real Packet Tunnel;
- handshake and real traffic;
- DNS/IPv4/IPv6 verification;
- reconnect, server switch, sleep/wake, background and extension restart;
- RSS/CPU qualification;
- real App Store/TestFlight purchase and restore evidence where applicable.

The repository's iPhone qualification matrix must remain blank for these rows until a real device run is attached. Never convert a parser/runtime result into `tested` device evidence.

## Reviewer consistency

Before submission, verify that these surfaces describe the same product:

1. App UI and screenshots.
2. App Store metadata.
3. Privacy disclosure and Privacy Policy.
4. Review clarification dossier.
5. TestFlight release notes.
6. Protocol matrix / release blocker ledger.
7. Actual binary behavior.

A release is not considered complete if one of these surfaces describes a removed Free/Premium mode or claims device evidence that has not been recorded.
