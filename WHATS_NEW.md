# What's New — VPN Direct 1.0.11 (63)

Release date: 2026-09-08  
Git tag: `v1.0.11.63`  
App build: `63` (TestFlight)  
Prior tag: `v1.0.11` (build 33)

## App Store / short What's New

- Home Screen widget toggles VPN **without opening the app**; larger power button on small size
- Status labels: **Включен** / **Включить** (live NE status + timeline reload)
- Control Center control hardened (safe value provider; App Store profile with Network Extension)
- Imported subscriptions no longer gated as Free/Premium; Russian bypass routing stabilized
- Tunnel / widget reliability: no WidgetKit reloads inside the packet tunnel; Control Center early-stop guard

## Product detail

### Widgets (build 63)

- Home Screen: `Button(intent:)` toggle — does **not** deep-link into the app
- Small widget: larger Aladdin power medallion with balanced padding
- Status text tracks connection: **Включен** when on, **Включить** when off
- Control Center: `ServiceToggleControl` first in `WidgetBundle`; provider never throws
- Widget extension signed with `packet-tunnel-provider` for live `NETunnelProviderManager` status

### Connection & access

- Third-party / imported profiles keep access and are not expire-disconnected as Free/Premium
- Russian bypass (Обход РФ): `http_client` detour via `proxy` (no conflicting `download_detour`)
- Deep-link `vpndirect://toggle` remains available for accessory / legacy paths

### Stability

- Packet tunnel no longer calls `WidgetCenter` / Control Center reloads (was tearing down `command.sock`)
- Control Center stale `SetValueIntent(false)` ignored for ~12s after dial
- Widget status published from the app; home timelines reload on connect/disconnect

## TestFlight

| Field | Value |
| --- | --- |
| Marketing | **1.0.11** |
| Build | **63** |
| Upload | App Store Connect — processed 2026-09-08 |

See [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md). Prefer **63+**.

## Device note

SFI Debug Wi-Fi install remains available for engineering. Packet Tunnel still needs interactive VPN permission on first connect.
