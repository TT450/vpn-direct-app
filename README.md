# VPN Direct

**VPN Direct — быстрый VPN для Apple**

Нативный клиент для **iOS / macOS / tvOS** на базе [sing-box](https://github.com/SagerNet/sing-box) и Libbox. Импорт стандартных `vless://` ссылок, подписки, Network Extension.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-lightgrey.svg)](#)
[![Version](https://img.shields.io/badge/version-1.0.0-informational.svg)](#)

> Этот репозиторий — **публичный исходный код** приложения VPN Direct (GPLv3), чтобы сообщество и пользователи App Store могли проверить, собрать и сверить клиент с тем, что распространяется в бинарном виде.

---

## Идентификаторы (публичные)

| | |
| --- | --- |
| App name | VPN Direct |
| Bundle ID | `com.vpndirect.vpndirectapp` |
| Packet Tunnel | `com.vpndirect.vpndirectapp.SingBoxPacketTunnel` |
| App Group | `group.com.vpndirect.vpndirectapp` |
| URL scheme | `vpndirect://` |

Signing Team ID и ключи App Store Connect **не** хранятся в этом репозитории — задайте их локально в Xcode / `DEVELOPMENT_TEAM` / env (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, `FASTLANE_TEAM_ID`).

---

## Возможности

- Импорт произвольных `vless://` (TLS / REALITY / WS / gRPC / HTTPUpgrade / **XHTTP**)
- Подписки и сборка конфигов sing-box
- Туннель через Network Extension + **Libbox**
- **VPN Direct Core 0.1** — воспроизводимая сборка Libbox из thin-fork [sing-box-lx](https://github.com/Leadaxe/sing-box-lx) (XHTTP, AmneziaWG, MASQUE CONNECT-IP, VLESS encryption)
- Capability Registry: UI и builders читают возможности связанного Libbox

---

## Основа

Модифицированный форк **[sing-box for Apple](https://github.com/SagerNet/sing-box-for-apple)** (SFI / SFM / SFT) — nekohasekai / SagerNet.

| Компонент | Источник |
| --- | --- |
| Apple UI / NE | этот репозиторий (форк sing-box-for-apple) |
| Proxy engine | Libbox из `core/sing-box` → [sing-box-lx](https://github.com/Leadaxe/sing-box-lx) |
| Upstream core | [SagerNet/sing-box](https://github.com/SagerNet/sing-box) |

См. также: [`NOTICE`](NOTICE), [`docs/core/DONORS.md`](docs/core/DONORS.md), [`docs/core/LICENSE_AUDIT.md`](docs/core/LICENSE_AUDIT.md).

---

## Быстрый старт (сборка)

### Требования

- macOS + Xcode
- Go (см. pin в `core/VERSION` / `core/sing-box/go.version`)
- Apple Developer Team и entitlements (Network Extension, App Group)

### 1. Клонирование

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app
```

Если `core/sing-box` пуст:

```bash
./scripts/bootstrap_core.sh
```

### 2. Libbox

```bash
make libbox-backup-stock   # если уже есть stock framework
make libbox                # → Libbox.xcframework
```

Подробности: [`docs/core/BUILDING.md`](docs/core/BUILDING.md).

### 3. Приложение

1. Откройте `sing-box.xcodeproj`
2. Схема **SFI** (iOS), **SFM** / **SFM.System** (macOS) или **SFT** (tvOS)
3. Подпишите своим Team ID и профилями
4. Убедитесь, что App Group и bundle ID существуют в Developer Portal

```bash
xcodebuild -scheme SFI -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData -allowProvisioningUpdates build
```

### Проверки

```bash
make check-fixtures
```

Документация ядра: [`docs/core/ARCHITECTURE.md`](docs/core/ARCHITECTURE.md) · [`docs/core/PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md).

---

## Структура репозитория

```text
├── SFI / SFM / SFT     # приложения Apple
├── Extension/          # Packet Tunnel
├── Library/            # Libbox bridge, builders, capabilities
├── ApplicationLibrary/ # UI (VPN Direct)
├── scripts/            # bootstrap + build_libbox
├── core/               # VERSION pins + overlays; sing-box submodule
├── docs/core/          # архитектура, лицензии, матрица протоколов
└── tests/fixtures/     # regression fixtures (без секретов)
```

`Libbox.xcframework` **не** хранится в git — собирается скриптами из исходников ядра.

---

## Лицензия

**GNU General Public License v3** (или новее) — см. [`LICENSE`](LICENSE).

```
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>
Copyright (C) 2026 VPN Direct contributors
```

### Соответствие App Store / GPLv3

При распространении бинарников (App Store, TestFlight, sideload) GPLv3 требует, чтобы получатели могли получить **соответствующий исходный код** этого модифицированного клиента, включая скрипты сборки Libbox. Этот публичный репозиторий — оферта исходников для проверки сообществом.

---

## Участие

См. [`CONTRIBUTING.md`](CONTRIBUTING.md). Уязвимости — [`SECURITY.md`](SECURITY.md).

---

## Отказ от ответственности

VPN Direct — клиент для ваших конфигов. Авторы не предоставляют VPN-серверы «из коробки» и не несут ответственности за нарушение местного законодательства при использовании туннеля.
