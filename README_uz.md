<p align="center">
  <img src="docs/brand/github-hero.svg" alt="VPN Direct" width="100%" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ru.md">Русский</a> ·
  <a href="README_uz.md"><b>Oʻzbekcha</b></a> ·
  <a href="README_zh.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/TT450/vpn-direct-app/actions/workflows/core-baseline.yml"><img src="https://github.com/TT450/vpn-direct-app/actions/workflows/core-baseline.yml/badge.svg" alt="Core baseline" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-2563EB.svg?style=flat-square" alt="GPLv3" /></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-111827.svg?style=flat-square" alt="Apple platforms" />
  <a href="https://github.com/TT450/vpn-direct-app/stargazers"><img src="https://img.shields.io/github/stars/TT450/vpn-direct-app?style=flat-square" alt="GitHub stars" /></a>
  <a href="https://t.me/vpndirectbot"><img src="https://img.shields.io/badge/Telegram-@vpndirectbot-229ED9?style=flat-square&logo=telegram&logoColor=white" alt="Telegram" /></a>
</p>

<p align="center"><b>Apple uchun native VPN klient — o‘zining qayta ishlab chiqariladigan, capability-driven Core’i sing-box asosida.</b></p>

<p align="center">
  <a href="https://apps.apple.com/app/id6807402257"><b>App Store</b></a> ·
  <a href="docs/core/ARCHITECTURE.md"><b>Arxitektura</b></a> ·
  <a href="docs/core/PROTOCOL_MATRIX.md"><b>Protokollar</b></a> ·
  <a href="docs/core/BUILDING.md"><b>Build</b></a> ·
  <a href="CONTRIBUTING.md"><b>Contribute</b></a>
</p>

---

## VPN Direct

VPN Direct — **iOS, macOS va tvOS** uchun open-source VPN klient.

Apple ilovasi `NetworkExtension` / `PacketTunnelProvider` arxitekturasini saqlaydi; tarmoq qatlami esa **VPN Direct Core** sifatida rivojlanadi — sing-box va mos keluvchi kengaytmalar asosidagi yupqa, qayta ishlab chiqariladigan Core.

To‘rt tamoyil:

- **Apple bilan native integratsiya** — tizim VPN tunnel, Network Extension lifecycle.
- **Capability-driven Core** — ilova bog‘langan Core’dan real imkoniyatlarni so‘raydi.
- **Qayta ishlab chiqariladigan buildlar** — Core versiyasi, sing-box pin, Go, gomobile va profil taglari kuzatiladi.
- **Jim protokol almashtirish yo‘q** — qo‘llab-quvvatlanmagan funksiya aniq xato beradi.

## Nima uchun VPN Direct Core?

VPN Direct Core Apple klientini barqaror saqlab, tarmoq qatlamini mustaqil qo‘llab-quvvatlash imkonini beradi.

```text
Subscription / Config → Content Detector → Universal Parser / Adapters
→ NormalizedSubscription → Location → Node
→ Capability Resolver + Builder → VPN Direct Core → Libbox → NetworkExtension
```

## Hozirgi Core holati

**So‘nggi reliz:** [`v1.0.5`](https://github.com/TT450/vpn-direct-app/releases/tag/v1.0.5)

Builder/parser borligi — hali `tested` / production emas. Holat: [Protocol Matrix](docs/core/PROTOCOL_MATRIX.md).

| Yo‘nalish | Holat |
| --- | --- |
| Libbox + Core baseline CI | Tayyor |
| ABI + CapabilityJSON (fail-closed) | Tayyor |
| Remnawave/Happ topology | Tayyor |
| VLESS + XHTTP/PQ / HY2 / multi-scheme parsers | Parser+runtime; interop davom etmoqda |
| Clash YAML + content detector + production gate | Tayyor |
| Mieru | Swift parse fail-closed; Core runtime yo‘q |
| CONNECT-UDP / Tailscale / OpenVPN | `out_of_scope` |

## Build profillari

| Profil | Maqsad |
| --- | --- |
| `vpn_direct_ios_minimal` | Kichik Apple/NE baseline |
| `vpn_direct_ios` | Default Apple profil |
| `vpn_direct_full` | Dev / kengaytirilgan protokol yuzasi |

## Manbadan build

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app
./scripts/bootstrap_core.sh
make libbox
make check-fixtures
make check-abi
```

Scheme’lar: iOS `SFI`, macOS `SFM` / `SFM.System`, tvOS `SFT`. Batafsil: [`docs/core/BUILDING.md`](docs/core/BUILDING.md).

## Hujjatlar

[Docs index](docs/README.md) · [Architecture](docs/core/ARCHITECTURE.md) · [Protocol Matrix](docs/core/PROTOCOL_MATRIX.md) · [Production Audit](docs/core/PRODUCTION_READINESS_AUDIT.md) · [Roadmap](ROADMAP.md) · [What's New](WHATS_NEW.md) · [Support](SUPPORT.md)

## Litsenziya

**GPLv3 or later** — [`LICENSE`](LICENSE), [`NOTICE`](NOTICE).

---

<p align="center">
  <b>VPN Direct</b><br/>
  Native Apple client · reproducible Core · explicit capabilities
</p>
