<p align="center">
  <img src="docs/brand/github-hero.svg" alt="VPN Direct" width="100%" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ru.md"><b>Русский</b></a> ·
  <a href="README_uz.md">Oʻzbekcha</a> ·
  <a href="README_zh.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/TT450/vpn-direct-app/actions/workflows/core-baseline.yml"><img src="https://github.com/TT450/vpn-direct-app/actions/workflows/core-baseline.yml/badge.svg" alt="Core baseline" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-2563EB.svg?style=flat-square" alt="GPLv3" /></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-111827.svg?style=flat-square" alt="Apple platforms" />
  <a href="https://github.com/TT450/vpn-direct-app/stargazers"><img src="https://img.shields.io/github/stars/TT450/vpn-direct-app?style=flat-square" alt="GitHub stars" /></a>
  <a href="https://t.me/vpndirectbot"><img src="https://img.shields.io/badge/Telegram-@vpndirectbot-229ED9?style=flat-square&logo=telegram&logoColor=white" alt="Telegram" /></a>
</p>

<p align="center"><b>Нативный VPN-клиент для Apple со своим воспроизводимым, capability-driven Core на базе sing-box.</b></p>

<p align="center">
  <a href="https://apps.apple.com/app/id6807402257"><b>App Store</b></a> ·
  <a href="docs/core/ARCHITECTURE.md"><b>Архитектура</b></a> ·
  <a href="docs/core/PROTOCOL_MATRIX.md"><b>Матрица протоколов</b></a> ·
  <a href="docs/core/BUILDING.md"><b>Сборка</b></a> ·
  <a href="CONTRIBUTING.md"><b>Contributing</b></a>
</p>

---

## VPN Direct

VPN Direct — open-source VPN-клиент для **iOS, macOS и tvOS**.

Apple-приложение сохраняет проверенную архитектуру `NetworkExtension` / `PacketTunnelProvider`, а сетевой слой развивается как **VPN Direct Core** — тонкий воспроизводимый Core на sing-box и совместимых расширениях.

Четыре принципа проекта:

- **Нативная интеграция с Apple** — системный VPN-туннель, жизненный цикл Network Extension и поддержка платформ Apple.
- **Capability-driven Core** — приложение спрашивает связанный Core, что он реально умеет, а не угадывает.
- **Воспроизводимые сборки** — версия Core, pin sing-box, Go, gomobile и build-профили зафиксированы.
- **Без тихой подмены протоколов** — неподдерживаемые фичи падают явно, а не превращаются в другой транспорт.

## Зачем VPN Direct Core?

VPN Direct Core держит Apple-клиент стабильным и делает сетевой слой независимо сопровождаемым.

```text
Subscription / Config
        │
        ▼
Content Detector
        │
        ▼
Universal Parser / Format Adapters
        │
        ▼
NormalizedSubscription → Location → Node
        │
        ▼
Capability Resolver + Outbound Builder
        │
        ▼
VPN Direct Core (Libbox / sing-box)
        │
        ▼
NetworkExtension
```

Core намеренно близок к upstream sing-box. Кастомные возможности изолируются build-тегами, overlays или небольшими патчами, чтобы обновления upstream оставались реалистичными.

## Текущий статус Core

**Последний релиз:** [`v1.0.6`](https://github.com/TT450/vpn-direct-app/releases/tag/v1.0.6) · pin Core: [`core/VERSION`](core/VERSION).

Фича не считается **production / `tested`** только из‑за builder. Нужен полный путь:

`import → валидация Core → старт Packet Tunnel → handshake → TCP/UDP → DNS → reconnect → память на iOS`

Актуальный статус по строкам — [Protocol Matrix](docs/core/PROTOCOL_MATRIX.md) · [`core/protocol-matrix.json`](core/protocol-matrix.json).

| Область | Состояние |
| --- | --- |
| Свой пайплайн Libbox + Core baseline CI | Реализован |
| ABI Core + CapabilityJSON (fail-closed) | Реализован |
| Remnawave / Happ topology (locations, Auto, detour) | Реализован (harvest P0) |
| VLESS TCP / TLS / REALITY / WS / gRPC / HTTPUpgrade | Runtime baseline |
| VLESS XHTTP / encryption (PQ) | Parser + runtime; interop в процессе |
| Hysteria / Hysteria2 | Parser + runtime; interop в процессе |
| VMess / Trojan / SS / TUIC / AnyTLS / ShadowTLS / Naive | Parser + builder; interop в процессе |
| WireGuard / AmneziaWG 2–3.1 | Parser + runtime; device-квалификация в процессе |
| MASQUE CONNECT-IP / WARP | Parser + runtime; квалификация в процессе |
| Clash / Mihomo YAML (только proxies) | Реализован |
| Content detector + production gate | Реализован (`make check-production-ready`) |
| Mieru | Parser + Core (`with_mieru`); interop planned |
| Interop lab / evidence `tested` | Каркасы + checklist; live evidence pending |
| CONNECT-UDP / Tailscale / OpenVPN | `out_of_scope` для Core 1.x |

## Архитектура

```text
┌───────────────────────────────────────────────┐
│                 VPN Direct App                │
│          SwiftUI · iOS · macOS · tvOS         │
└──────────────────────┬────────────────────────┘
                       │
                       ▼
┌───────────────────────────────────────────────┐
│              Network Extension                │
│     PacketTunnelProvider · tunnel lifecycle   │
└──────────────────────┬────────────────────────┘
                       │
                       ▼
┌───────────────────────────────────────────────┐
│              VPN Direct Core API              │
│     ABI · capabilities · builders · errors    │
└──────────────────────┬────────────────────────┘
                       │
                       ▼
┌───────────────────────────────────────────────┐
│                    Libbox                     │
│      sing-box-lx pin + isolated overlays      │
└──────────────────────┬────────────────────────┘
                       │
                       ▼
┌───────────────────────────────────────────────┐
│                 sing-box stack                │
└───────────────────────────────────────────────┘
```

Подробнее: [`docs/core/ARCHITECTURE.md`](docs/core/ARCHITECTURE.md)

## Build-профили

| Профиль | Назначение |
| --- | --- |
| `vpn_direct_ios_minimal` | Компактный Apple/NE baseline |
| `vpn_direct_ios` | Профиль по умолчанию для Apple |
| `vpn_direct_full` | Dev / расширенная поверхность протоколов |

Профили: [`scripts/tags/`](scripts/tags/).

## Сборка из исходников

**Нужно:** macOS, Xcode, версия Go из [`core/VERSION`](core/VERSION), Apple Developer Team с Network Extension / App Group.

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app

./scripts/bootstrap_core.sh
make libbox
make check-fixtures
make check-abi
make check-production-ready
```

Откройте `sing-box.xcodeproj`:

| Платформа | Scheme |
| --- | --- |
| iOS | `SFI` |
| macOS | `SFM` / `SFM.System` |
| tvOS | `SFT` |

Детали: [`docs/core/BUILDING.md`](docs/core/BUILDING.md)

## Карта репозитория

```text
vpn-direct-app/
├── ApplicationLibrary/      UI и app-specific компоненты
├── Extension/               Packet Tunnel / Network Extension
├── Library/                 Core bridge, подписки, VPNDirect parsers/builders
├── core/
│   ├── VERSION              pins Core/toolchain
│   ├── protocol-matrix.json машиночитаемая матрица
│   ├── overlays/            capability-слой Libbox
│   └── sing-box/            pinned submodule Core
├── scripts/                 build_libbox, check-fixtures, check-production-ready, tags/
├── tests/fixtures/          regression fixtures
├── interop/                 interop scaffolds + evidence/
├── docs/core/               инженерная документация Core
└── docs/device/             iPhone qualification checklist
```

## Документация

| Документ | Назначение |
| --- | --- |
| [Индекс docs](docs/README.md) | Карта документации |
| [Architecture](docs/core/ARCHITECTURE.md) | Дизайн Core и Apple-интеграция |
| [Build Guide](docs/core/BUILDING.md) | Воспроизведение Libbox и Apple-сборок |
| [Protocol Matrix](docs/core/PROTOCOL_MATRIX.md) | Что парсится, компилируется, тестируется |
| [Production Audit](docs/core/PRODUCTION_READINESS_AUDIT.md) | Честный статус по реальному коду |
| [Roadmap](ROADMAP.md) | Публичный roadmap |
| [What's New](WHATS_NEW.md) | Релизные заметки последнего тега |
| [Mieru Status](docs/core/MIERU_DEFERRED.md) | Статус Mieru |
| [iPhone Qualification](docs/device/IPHONE_QUALIFICATION.md) | Чеклист device evidence |

## Публичные идентификаторы

| | |
| --- | --- |
| App | VPN Direct |
| Bundle ID | `com.vpndirect.vpndirectapp` |
| Packet Tunnel | `com.vpndirect.vpndirectapp.SingBoxPacketTunnel` |
| App Group | `group.com.vpndirect.vpndirectapp` |
| URL scheme | `vpndirect://` |
| App Store ID | `6807402257` |

Секреты и signing credentials в репозитории не хранятся.

## Contributing

Перед PR читайте [`CONTRIBUTING.md`](CONTRIBUTING.md).

Для протокольных изменений:
- добавьте/обновите regression fixtures;
- обновите Protocol Matrix;
- не коммитьте реальные subscription URL, ключи, credentials или signing secrets.

Security: [`SECURITY.md`](SECURITY.md), не публичные bug report'ы.

## Upstream и благодарности

- [SagerNet/sing-box](https://github.com/SagerNet/sing-box)
- [SagerNet/sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple)
- [Leadaxe/sing-box-lx](https://github.com/Leadaxe/sing-box-lx)
- экосистема sing-box / Libbox

См. [`docs/core/DONORS.md`](docs/core/DONORS.md).

## Лицензия

**GNU General Public License v3 or later.**

См. [`LICENSE`](LICENSE), [`NOTICE`](NOTICE), [`docs/core/LICENSE_AUDIT.md`](docs/core/LICENSE_AUDIT.md).

---

<p align="center">
  <b>VPN Direct</b><br/>
  Native Apple client · reproducible Core · explicit capabilities
</p>
