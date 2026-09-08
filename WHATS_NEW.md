# What's New — VPN Direct 1.0.11

Release date: 2026-09-08  
Git tag: `v1.0.11`  
App build: `33`

## App Store / short What's New

- Home / Control Center / Lock Screen widgets for quick VPN toggle
- Connection mode rename: **5G** (was «Антиблокировка»)
- Subscriptions & Profile: stable vertical scroll, unified page chrome
- Home status row polish (kicker, status dot, typography)
- Import: QR, clipboard, URL, file, paste config; offline/online ping

## Product detail

### Widgets
- Control Center toggle branded **VPN Direct** (Подключено / Отключено)
- Home Screen: small + medium status widgets with on/off action
- Lock Screen: circular, rectangular, and inline accessories

### Connection modes
- Profile sheet label **5G** (legacy stored «Антиблокировка» migrates automatically)

### DirectUI polish
- Shared page heading scale across Home / Subscriptions / Profile
- Home kicker `КЛИЕНТ / VPN`; status indicator after the title
- Subscriptions page vertical-only scroll (no horizontal “website” pan)
- Server picker: full-width **Пинг**; TCP ping when offline, Libbox urlTest when connected
- Metrics / action rows aligned; refresh subscription parity with TheTochka flow

### Import & access
- Add-subscription menu: QR, clipboard (link or raw config), manual URL, file, paste config
- Local profile importer for file / text configs

## TestFlight

See [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) for public join link guidance and how to invite testers (Internal / External).

## Device note

SFI Wi-Fi install/launch on physical iPhone remains available for engineering builds. Packet Tunnel connect still needs interactive VPN permission on device.
