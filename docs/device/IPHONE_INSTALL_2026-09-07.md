# iPhone install evidence — 2026-09-07

## Device

- Model: iPhone 13
- Identifier: `E4788B50-0966-5146-B4A1-207CAF2E4586` (Wi-Fi paired)
- Bundle ID: `com.vpndirect.vpndirectapp`
- Scheme: `SFI`
- Development team: `6D563CF4V3`

## Build

- Command: `xcodebuild -project sing-box.xcodeproj -scheme SFI -configuration Debug -destination 'platform=iOS,id=E4788B50-0966-5146-B4A1-207CAF2E4586' DEVELOPMENT_TEAM=6D563CF4V3 build`
- Result: **BUILD SUCCEEDED**
- App: `build/DerivedData/Build/Products/Debug-iphoneos/sing-box.app`
- Fix applied for compile: `SubscriptionHTTP.swift` header-key iteration typing

## Install / launch

| Step | Result |
| --- | --- |
| `devicectl device install app` | **PASS** |
| `devicectl device process launch` (`com.vpndirect.vpndirectapp`) | **PASS** |

## Not yet proven (still EXTERNAL / NOT TESTED)

| Check | Status |
| --- | --- |
| VPN permission flow | NOT TESTED (requires user interaction) |
| Packet Tunnel Extension start | NOT TESTED |
| TUN open / DNS / IPv4 / IPv6 | NOT TESTED |
| Protocol handshake | NOT TESTED (needs battle keys / live servers) |

## Notes

Install + launch evidence closes the *install/launch* portion of `REQ-DEVICE-iphone-install`.
Tunnel and handshake remain blocked on interactive VPN permission and live credentials.
