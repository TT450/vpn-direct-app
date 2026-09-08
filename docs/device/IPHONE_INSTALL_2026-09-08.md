# iPhone install evidence — 2026-09-08

## Device

- Model: iPhone 13
- Identifier: `E4788B50-0966-5146-B4A1-207CAF2E4586` (Wi-Fi paired)
- Bundle ID: `com.vpndirect.vpndirectapp`
- Scheme: `SFI`
- Configuration: Debug
- Development team: `6D563CF4V3`
- MARKETING_VERSION: `1.0.10` (CFBundleShortVersionString)

## Build

- Command: `xcodebuild -project sing-box.xcodeproj -scheme SFI -configuration Debug -destination 'platform=iOS,id=E4788B50-0966-5146-B4A1-207CAF2E4586' -derivedDataPath build/DerivedData DEVELOPMENT_TEAM=6D563CF4V3 build`
- Result: **BUILD SUCCEEDED** — **PASS**
- App: `build/DerivedData/Build/Products/Debug-iphoneos/sing-box.app`

## Install / launch

| Step | Result |
| --- | --- |
| `devicectl device install app` | **PASS** (after brief Wi-Fi reconnect; first attempt timed out while device was unavailable) |
| `devicectl device process launch` (`com.vpndirect.vpndirectapp`) | **PASS** |

### Install output (success)

- bundleID: `com.vpndirect.vpndirectapp`
- installationURL: `file:///private/var/containers/Bundle/Application/4C4DDFD8-9149-4684-AC10-DE70852300F2/sing-box.app/`

### Launch output (success)

- Launched application with `com.vpndirect.vpndirectapp` bundle identifier.

## Not yet proven (still EXTERNAL / NOT TESTED)

| Check | Status |
| --- | --- |
| VPN permission flow | NOT TESTED (requires user interaction) |
| Packet Tunnel Extension start | NOT TESTED |
| TUN open / DNS / IPv4 / IPv6 | NOT TESTED |
| Protocol handshake | NOT TESTED (needs battle keys / live servers) |

## Notes

Install + launch evidence for MARKETING_VERSION **1.0.10**. Tunnel and handshake remain blocked on interactive VPN permission and live credentials.
