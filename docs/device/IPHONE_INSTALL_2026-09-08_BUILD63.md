# iPhone install / TestFlight evidence — 2026-09-08 (build 63)

## Device (Debug SFI)

- Model: iPhone 13
- Identifier: `E4788B50-0966-5146-B4A1-207CAF2E4586`
- Bundle ID: `com.vpndirect.vpndirectapp`
- Marketing: **1.0.11** · Debug builds through **62** installed via `devicectl` during widget iteration

## TestFlight (Release)

| Field | Value |
| --- | --- |
| Version | **1.0.11** |
| Build | **63** |
| Upload | `fastlane ios release` — **PASS** (processed on App Store Connect 2026-09-08) |
| IPA | `build/fastlane/VPNDirect.ipa` |
| GitHub | [`v1.0.11.63`](https://github.com/TT450/vpn-direct-app/releases/tag/v1.0.11.63) |

## Notes

- Widget App Store profile recreated with Network Extension entitlements before export.
- Prefer TestFlight **63+** for in-widget toggle (no app open) and Control Center control.
- Packet Tunnel interactive VPN permission still required on first connect.
