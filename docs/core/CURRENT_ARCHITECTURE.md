# VPN Direct — Current Architecture (pre–Core 0.1)

## Apple layer

| Component | Path |
|-----------|------|
| iOS app | `SFI/` |
| macOS app | `SFM/`, `SFM.System/` |
| tvOS app | `SFT/` |
| Shared UI | `ApplicationLibrary/` |
| Shared networking / DB | `Library/` |
| Packet tunnel (iOS) | `Extension/PacketTunnelProvider.swift` → `Library/Network/ExtensionProvider.swift` |
| Platform bridge | `Library/Network/ExtensionPlatformInterface.swift` |
| Command IPC | `Library/Network/CommandClient.swift`, `CommandXPC.swift` |

Apps embed Network Extension; Libbox is linked into **Library** and used by the extension process.

## Core layer (today)

| Item | Value |
|------|--------|
| Framework | `Libbox.xcframework` (project root) |
| Source | Stock sing-box (external); **no in-repo build** |
| Documented build | `go run ./cmd/internal/build_libbox -target apple` from sing-box sources |
| App version | 1.0.0 (1) |
| Engine version | Runtime `LibboxVersion()`; RootHelper still shows leftover `1.13.0-alpha.21` |

## Configuration / parser (today)

| Builder | Path | Behavior |
|---------|------|----------|
| VLESS | `Library/Service/VLESSConfigBuilder.swift` | `vless://` only; XHTTP/splithttp **mapped to httpupgrade** |
| Subscriptions | `Library/Service/SubscriptionConfigBuilder.swift` | HTTP(S) fetch; sing-box JSON / XRAY_JSON / share lists; **skips XHTTP** nodes |
| Migrator | `Library/Service/SingBoxConfigMigrator.swift` | DNS/tun/domain_resolver for Libbox 1.13+ |

**Materialized protocols:** VLESS (plus passthrough of full sing-box JSON profiles).

**Recognized but not built from share lists:** `vmess://`, `ss://`, `trojan://`, `hy2://`, `hysteria2://`.

## UI coupling

DirectUI hardcodes VLESS/Reality marketing copy and sometimes mentions vmess without a builder. Capability Registry (Core 0.1) will decouple feature discovery from UI.

## Target after Core 0.1

```text
Apple app (unchanged NE)
  → Library
  → Libbox.xcframework (VPN Direct build)
  → core/sing-box (sing-box-lx thin fork submodule)
```
