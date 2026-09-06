<div align="center">

[**English**](README.md) · [**Русский 🇷🇺**](README_ru.md) · [**Oʻzbekcha 🇺🇿**](README_uz.md) · [**简体中文 🇨🇳**](README_zh.md)

<br/>

<img src="docs/brand/logo.png" alt="VPN Direct" width="128" />

# VPN Direct

**面向 Apple 的原生 VPN 客户端 — 开源，GPLv3**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-lightgrey.svg?style=flat-square)](#)
[![Telegram](https://img.shields.io/badge/Telegram-@vpndirectbot-26A5E4?style=flat-square&logo=telegram)](https://t.me/vpndirectbot)

</div>

## 什么是 VPN Direct？

VPN Direct 是基于 [sing-box](https://github.com/SagerNet/sing-box) 与 Libbox（Network Extension）的 **iOS / macOS / tvOS** 原生 VPN 客户端。可导入标准 `vless://` 链接与订阅，并通过本仓库的 GPLv3 源码核对 App Store 构建。

<div align="center">

<a href="https://apps.apple.com/app/id6807402257">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="App Store" height="54"/>
</a>
&nbsp;&nbsp;
<a href="https://t.me/vpndirectbot">
  <img src="https://img.shields.io/badge/Telegram-@vpndirectbot-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram"/>
</a>

</div>

## 🚀 主要特性

✈️ 原生 Apple：iOS、macOS、tvOS

🟡 VLESS（TLS / REALITY）、WS、gRPC、HTTPUpgrade、**XHTTP**

🟡 订阅与 sing-box 配置生成

🛡 开源（GPLv3）+ VPN Direct Core 0.1

📱 [App Store](https://apps.apple.com/app/id6807402257) · Telegram [@vpndirectbot](https://t.me/vpndirectbot)

## ⚙️ 从源码构建

完整说明见 [README.md](README.md) 与 [`docs/core/BUILDING.md`](docs/core/BUILDING.md)。

```bash
git clone --recurse-submodules https://github.com/TT450/vpn-direct-app.git
cd vpn-direct-app && ./scripts/bootstrap_core.sh && make libbox
```

## 📄 许可

**GPLv3** — [`LICENSE`](LICENSE)。贡献指南：[`CONTRIBUTING.md`](CONTRIBUTING.md)。
