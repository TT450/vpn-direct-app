<p align="center">
  <img src="docs/brand/github-hero.svg" alt="VPN Direct" width="100%" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ru.md">Русский</a> ·
  <a href="README_uz.md">Oʻzbekcha</a> ·
  <a href="README_zh.md"><b>简体中文</b></a>
</p>

<p align="center">
  <a href="https://github.com/TT450/vpn-direct-app/actions/workflows/core-baseline.yml"><img src="https://github.com/TT450/vpn-direct-app/actions/workflows/core-baseline.yml/badge.svg" alt="Core baseline" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-2563EB.svg?style=flat-square" alt="GPLv3" /></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-111827.svg?style=flat-square" alt="Apple platforms" />
  <a href="https://github.com/TT450/vpn-direct-app/stargazers"><img src="https://img.shields.io/github/stars/TT450/vpn-direct-app?style=flat-square" alt="GitHub stars" /></a>
  <a href="https://t.me/vpndirectbot"><img src="https://img.shields.io/badge/Telegram-@vpndirectbot-229ED9?style=flat-square&logo=telegram&logoColor=white" alt="Telegram" /></a>
</p>

<p align="center"><b>面向 Apple 的原生 VPN 客户端，自带可复现、capability-driven 的 sing-box Core。</b></p>

<p align="center">
  <a href="https://apps.apple.com/app/id6807402257"><b>App Store</b></a> ·
  <a href="docs/core/ARCHITECTURE.md"><b>架构</b></a> ·
  <a href="docs/core/PROTOCOL_MATRIX.md"><b>协议矩阵</b></a> ·
  <a href="docs/core/BUILDING.md"><b>构建</b></a> ·
  <a href="CONTRIBUTING.md"><b>贡献</b></a>
</p>

---

## VPN Direct

VPN Direct 是面向 **iOS、macOS、tvOS** 的开源 VPN 客户端。

Apple 应用保留成熟的 `NetworkExtension` / `PacketTunnelProvider` 架构；网络层演进为 **VPN Direct Core** —— 基于 sing-box 与兼容扩展的可复现薄 Core。

四项原则：

- **原生 Apple 集成** — 系统 VPN 隧道与 Network Extension 生命周期
- **Capability-driven Core** — 应用查询已链接 Core 的真实能力，而不是猜测
- **可复现构建** — Core 版本、sing-box pin、Go、gomobile 与构建配置均被记录
- **无静默协议替换** — 不支持的能力明确失败，而不是悄悄降级为另一种传输

## 为什么需要 VPN Direct Core？

在保持 Apple 客户端稳定的同时，让网络层可独立维护。

```text
Subscription / Config → Content Detector → Universal Parser / Adapters
→ NormalizedSubscription → Location → Node
→ Capability Resolver + Builder → VPN Direct Core → Libbox → NetworkExtension
```

## 当前 Core 状态

**最新发布：** [`v1.0.5`](https://github.com/TT450/vpn-direct-app/releases/tag/v1.0.5)

仅有 builder / parser **不等于** `tested` / production。权威状态见 [Protocol Matrix](docs/core/PROTOCOL_MATRIX.md)。

| 领域 | 状态 |
| --- | --- |
| Libbox 构建 + Core baseline CI | 已实现 |
| ABI + CapabilityJSON（fail-closed） | 已实现 |
| Remnawave/Happ 拓扑（locations / Auto / detour） | 已实现 |
| VLESS 基线 + XHTTP/PQ | Runtime / parser+runtime；互操作进行中 |
| Hysteria/HY2、VMess、Trojan、SS、TUIC、AnyTLS… | Parser + builder；互操作进行中 |
| WireGuard / AmneziaWG / MASQUE | Parser + runtime；真机资格认证进行中 |
| Clash YAML（仅 proxies）+ content detector | 已实现 |
| `make check-production-ready` | 已实现 |
| Mieru | Swift 解析 fail-closed；Core runtime 未注册 |
| CONNECT-UDP / Tailscale / OpenVPN | `out_of_scope` |

## 构建配置

| Profile | 用途 |
| --- | --- |
| `vpn_direct_ios_minimal` | 精简 Apple/NE 基线 |
| `vpn_direct_ios` | 默认 Apple 配置 |
| `vpn_direct_full` | 开发 / 扩展协议面 |

## 从源码构建

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app
./scripts/bootstrap_core.sh
make libbox
make check-fixtures
make check-abi
```

Scheme：iOS `SFI`，macOS `SFM` / `SFM.System`，tvOS `SFT`。详见 [`docs/core/BUILDING.md`](docs/core/BUILDING.md)。

## 文档

[文档索引](docs/README.md) · [架构](docs/core/ARCHITECTURE.md) · [协议矩阵](docs/core/PROTOCOL_MATRIX.md) · [生产就绪审计](docs/core/PRODUCTION_READINESS_AUDIT.md) · [Roadmap](ROADMAP.md) · [What's New](WHATS_NEW.md) · [Support](SUPPORT.md)

## 许可证

**GPLv3 or later** — 见 [`LICENSE`](LICENSE)、[`NOTICE`](NOTICE)。

---

<p align="center">
  <b>VPN Direct</b><br/>
  Native Apple client · reproducible Core · explicit capabilities
</p>
