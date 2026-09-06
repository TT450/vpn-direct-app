<div align="center">

[**English**](README.md) · [**Русский 🇷🇺**](README_ru.md) · [**Oʻzbekcha 🇺🇿**](README_uz.md) · [**简体中文 🇨🇳**](README_zh.md)

<br/>

<img src="docs/brand/logo.png" alt="VPN Direct" width="128" />

# VPN Direct

**Быстрый нативный VPN для Apple — открытый исходный код, GPLv3**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-lightgrey.svg?style=flat-square)](#)
[![Version](https://img.shields.io/badge/version-1.0.0-informational.svg?style=flat-square)](#)
[![Stars](https://img.shields.io/github/stars/TT450/vpn-direct-app?style=flat-square)](https://github.com/TT450/vpn-direct-app/stargazers)
[![Telegram](https://img.shields.io/badge/Telegram-@vpndirectbot-26A5E4?style=flat-square&logo=telegram)](https://t.me/vpndirectbot)

</div>

## Что такое VPN Direct?

VPN Direct — **нативный VPN-клиент для Apple** (iOS / macOS / tvOS) на базе [sing-box](https://github.com/SagerNet/sing-box) и Libbox (Network Extension). Импорт `vless://` и подписок, системный VPN-туннель и возможность сверить App Store-бинарник с этим публичным исходником (GPLv3).

Этот репозиторий — **оферта исходников** для сборок App Store / TestFlight: сообщество может проверить, собрать и сравнить клиент.

<div align="center">

<a href="https://apps.apple.com/app/id6807402257">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Скачать в App Store" height="54"/>
</a>
&nbsp;&nbsp;
<a href="https://t.me/vpndirectbot">
  <img src="https://img.shields.io/badge/Открыть-Telegram%20бот-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram бот"/>
</a>

</div>

## 🚀 Основные возможности

✈️ **Нативно для Apple** — iOS, macOS и tvOS (SFI / SFM / SFT)

⭐ Удобный Direct UI: избранное, недавние серверы, access-флоу

🟡 **Протоколы и транспорты:** VLESS (TLS / REALITY), WS, gRPC, HTTPUpgrade, **XHTTP**

🟡 Подписки и генерация конфигов sing-box

🔄 Импорт подписок в один тап (`vpndirect://`, ссылки в стиле Happ / Streisand)

🛡 **Открытый код (GPLv3)** — воспроизводимый Libbox через VPN Direct Core 0.1

⚙ **VPN Direct Core** — thin-fork [sing-box-lx](https://github.com/Leadaxe/sing-box-lx): XHTTP, AmneziaWG, MASQUE CONNECT-IP, VLESS encryption + Capability Registry

📱 Доступно в **App Store**

## 🛍️ Где скачать

| Платформа | Ссылка |
| --- | --- |
| **iOS / macOS / tvOS** | [App Store](https://apps.apple.com/app/id6807402257) |
| **Telegram** | [@vpndirectbot](https://t.me/vpndirectbot) |
| **Исходники** | [Этот репозиторий](https://github.com/TT450/vpn-direct-app) |

## 🆔 Публичные идентификаторы

| | |
| --- | --- |
| App name | VPN Direct |
| Bundle ID | `com.vpndirect.vpndirectapp` |
| Packet Tunnel | `com.vpndirect.vpndirectapp.SingBoxPacketTunnel` |
| App Group | `group.com.vpndirect.vpndirectapp` |
| URL scheme | `vpndirect://` |
| App Store ID | `6807402257` |

Signing Team ID и ключи App Store Connect **не** хранятся в репозитории — задайте локально (`DEVELOPMENT_TEAM`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, `FASTLANE_TEAM_ID`). См. [`fastlane/SECRETS.example.md`](fastlane/SECRETS.example.md).

## 🧱 Архитектура

| Компонент | Источник |
| --- | --- |
| Apple UI / Network Extension | этот репозиторий (форк [sing-box for Apple](https://github.com/SagerNet/sing-box-for-apple)) |
| Proxy engine | Libbox из `core/sing-box` → [sing-box-lx](https://github.com/Leadaxe/sing-box-lx) |
| Upstream core | [SagerNet/sing-box](https://github.com/SagerNet/sing-box) |

Также: [`NOTICE`](NOTICE) · [`docs/core/DONORS.md`](docs/core/DONORS.md) · [`docs/core/LICENSE_AUDIT.md`](docs/core/LICENSE_AUDIT.md) · [`docs/core/ARCHITECTURE.md`](docs/core/ARCHITECTURE.md)

## ⚙️ Сборка из исходников

**Нужно:** macOS + Xcode, Go (pin в `core/VERSION`), Apple Developer Team с Network Extension и App Group.

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app
./scripts/bootstrap_core.sh   # если core/sing-box пуст
make libbox-backup-stock      # опционально
make libbox                   # → Libbox.xcframework
```

Откройте `sing-box.xcodeproj` → схема **SFI** (iOS), **SFM** / **SFM.System** (macOS) или **SFT** (tvOS). Подпишите своим Team ID.

```bash
make check-fixtures
```

Документация ядра: [`docs/core/BUILDING.md`](docs/core/BUILDING.md) · [`docs/core/PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md)

`Libbox.xcframework` **не** лежит в git — собирается из исходников Core.

## 📁 Структура репозитория

```text
├── SFI / SFM / SFT       # приложения Apple
├── Extension/            # Packet Tunnel
├── Library/              # Libbox bridge, builders, capabilities
├── ApplicationLibrary/   # UI (VPN Direct)
├── scripts/              # bootstrap + build_libbox
├── core/                 # VERSION pins + overlays; sing-box submodule
├── docs/                 # бренд + архитектура ядра
└── tests/fixtures/       # regression fixtures (без секретов)
```

## ✏️ Благодарности

Спасибо авторам и контрибьюторам:

- [Sing-box](https://github.com/SagerNet/sing-box)
- [Sing-box for Apple](https://github.com/SagerNet/sing-box-for-apple)
- [sing-box-lx](https://github.com/Leadaxe/sing-box-lx)
- nekohasekai / SagerNet и всем, кто стоит за Libbox

## 👩‍🏫 Участие

Приветствуем вклад сообщества — [`CONTRIBUTING.md`](CONTRIBUTING.md). Уязвимости: [`SECURITY.md`](SECURITY.md).

<div align="center">

[![Telegram](https://img.shields.io/badge/Telegram-@vpndirectbot-26A5E4?style=flat-square&logo=telegram)](https://t.me/vpndirectbot)
[![GitHub](https://img.shields.io/badge/GitHub-TT450%2Fvpn--direct--app-181717?style=flat-square&logo=github)](https://github.com/TT450/vpn-direct-app)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)

</div>

## 📄 Лицензия

**GNU General Public License v3** (или новее) — [`LICENSE`](LICENSE).

```
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>
Copyright (C) 2026 VPN Direct contributors
```

При распространении бинарников (App Store, TestFlight, sideload) GPLv3 требует, чтобы получатели могли получить **соответствующий исходный код** этого модифицированного клиента, включая скрипты сборки Libbox. Этот публичный репозиторий — такая оферта.

## ⚠️ Отказ от ответственности

VPN Direct — клиент для **ваших** конфигов. Авторы не предоставляют VPN-серверы «из коробки» и не несут ответственности за нарушение местного законодательства при использовании туннеля.
