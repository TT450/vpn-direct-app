<div align="center">

[**English**](README.md) · [**Русский 🇷🇺**](README_ru.md) · [**Oʻzbekcha 🇺🇿**](README_uz.md) · [**简体中文 🇨🇳**](README_zh.md)

<br/>

<img src="docs/brand/logo.png" alt="VPN Direct" width="128" />

# VPN Direct

**Fast native VPN client for Apple — open source, GPLv3**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-lightgrey.svg?style=flat-square)](#)
[![Version](https://img.shields.io/badge/version-1.0.0-informational.svg?style=flat-square)](#)
[![Stars](https://img.shields.io/github/stars/TT450/vpn-direct-app?style=flat-square)](https://github.com/TT450/vpn-direct-app/stargazers)
[![Telegram](https://img.shields.io/badge/Telegram-@vpndirectbot-26A5E4?style=flat-square&logo=telegram)](https://t.me/vpndirectbot)

</div>

## What is VPN Direct?

VPN Direct is a **native Apple VPN client** for **iOS / macOS / tvOS**, built on [sing-box](https://github.com/SagerNet/sing-box) and Libbox (Network Extension). Import standard `vless://` links and subscriptions, connect through a system VPN tunnel, and verify the binary against this public GPLv3 source tree.

This repository is the **source offer** for the App Store / TestFlight builds — so the community can review, build, and compare.

<div align="center">

<a href="https://apps.apple.com/app/id6807402257">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="54"/>
</a>
&nbsp;&nbsp;
<a href="https://t.me/vpndirectbot">
  <img src="https://img.shields.io/badge/Open-Telegram%20bot-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram bot"/>
</a>

</div>

## 🚀 Main features

✈️ **Apple-native** — iOS, macOS, and tvOS (SFI / SFM / SFT)

⭐ Clean Direct UI with favorites, recent servers, and access flows

🟡 **Protocols & transports:** VLESS (TLS / REALITY), WS, gRPC, HTTPUpgrade, **XHTTP**

🟡 Subscriptions and sing-box config generation

🔄 Auto / one-tap subscription import (`vpndirect://`, Happ / Streisand-style links)

🛡 **Open source (GPLv3)** — reproducible Libbox via VPN Direct Core 0.1

⚙ **VPN Direct Core** — thin fork of [sing-box-lx](https://github.com/Leadaxe/sing-box-lx): XHTTP, AmneziaWG, MASQUE CONNECT-IP, VLESS encryption + Capability Registry

📱 Available on the **App Store**

## 🛍️ Get it

| Platform | Download |
| --- | --- |
| **iOS / macOS / tvOS** | [App Store](https://apps.apple.com/app/id6807402257) |
| **Telegram** | [@vpndirectbot](https://t.me/vpndirectbot) |
| **Source** | [Clone this repo](https://github.com/TT450/vpn-direct-app) |

## 🆔 Public identifiers

| | |
| --- | --- |
| App name | VPN Direct |
| Bundle ID | `com.vpndirect.vpndirectapp` |
| Packet Tunnel | `com.vpndirect.vpndirectapp.SingBoxPacketTunnel` |
| App Group | `group.com.vpndirect.vpndirectapp` |
| URL scheme | `vpndirect://` |
| App Store ID | `6807402257` |

Signing Team ID and App Store Connect API keys are **not** stored here — set them locally (`DEVELOPMENT_TEAM`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, `FASTLANE_TEAM_ID`). See [`fastlane/SECRETS.example.md`](fastlane/SECRETS.example.md).

## 🧱 Architecture

| Component | Source |
| --- | --- |
| Apple UI / Network Extension | this repository (fork of [sing-box for Apple](https://github.com/SagerNet/sing-box-for-apple)) |
| Proxy engine | Libbox from `core/sing-box` → [sing-box-lx](https://github.com/Leadaxe/sing-box-lx) |
| Upstream core | [SagerNet/sing-box](https://github.com/SagerNet/sing-box) |

Also: [`NOTICE`](NOTICE) · [`docs/core/DONORS.md`](docs/core/DONORS.md) · [`docs/core/LICENSE_AUDIT.md`](docs/core/LICENSE_AUDIT.md) · [`docs/core/ARCHITECTURE.md`](docs/core/ARCHITECTURE.md)

## ⚙️ Build from source

**Requirements:** macOS + Xcode, Go (see pin in `core/VERSION`), Apple Developer Team with Network Extension + App Group.

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app
./scripts/bootstrap_core.sh   # if core/sing-box is empty
make libbox-backup-stock      # optional, if you already have stock Libbox
make libbox                   # → Libbox.xcframework
```

Open `sing-box.xcodeproj` → scheme **SFI** (iOS), **SFM** / **SFM.System** (macOS), or **SFT** (tvOS). Sign with your Team ID.

```bash
make check-fixtures
```

Full Core docs: [`docs/core/BUILDING.md`](docs/core/BUILDING.md) · [`docs/core/PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md)

`Libbox.xcframework` is **not** committed — build it from Core sources.

## 📁 Repository layout

```text
├── SFI / SFM / SFT       # Apple apps
├── Extension/            # Packet Tunnel
├── Library/              # Libbox bridge, builders, capabilities
├── ApplicationLibrary/   # UI (VPN Direct)
├── scripts/              # bootstrap + build_libbox
├── core/                 # VERSION pins + overlays; sing-box submodule
├── docs/                 # brand + core architecture
└── tests/fixtures/       # regression fixtures (no secrets)
```

## ✏️ Acknowledgements

Thanks to the authors and contributors of:

- [Sing-box](https://github.com/SagerNet/sing-box)
- [Sing-box for Apple](https://github.com/SagerNet/sing-box-for-apple)
- [sing-box-lx](https://github.com/Leadaxe/sing-box-lx)
- nekohasekai / SagerNet and everyone behind Libbox

## 👩‍🏫 Collaboration

Community contributions welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md). Security reports: [`SECURITY.md`](SECURITY.md).

<div align="center">

[![Telegram](https://img.shields.io/badge/Telegram-@vpndirectbot-26A5E4?style=flat-square&logo=telegram)](https://t.me/vpndirectbot)
[![GitHub](https://img.shields.io/badge/GitHub-TT450%2Fvpn--direct--app-181717?style=flat-square&logo=github)](https://github.com/TT450/vpn-direct-app)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)

</div>

## 📄 License

**GNU General Public License v3** (or later) — see [`LICENSE`](LICENSE).

```
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>
Copyright (C) 2026 VPN Direct contributors
```

When distributing binaries (App Store, TestFlight, sideload), GPLv3 requires that recipients can obtain the **corresponding source** for this modified client, including Libbox build scripts. This public repository is that offer.

## ⚠️ Disclaimer

VPN Direct is a client for **your** configs. Authors do not ship VPN servers “out of the box” and are not responsible for unlawful use of the tunnel under local law.
