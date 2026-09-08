# VPN Direct Core architecture

App release **v1.0.10** · Core pin: [`core/VERSION`](../../core/VERSION)

## Strategy

Upstream **sing-box** remains the foundation. VPN Direct Core is a **thin fork** (starting from [sing-box-lx](https://github.com/Leadaxe/sing-box-lx)): extra features live in new files / build tags; upstream files touched only at marked seams.

```text
SagerNet/sing-box
        │
        ▼
core/sing-box (submodule: sing-box-lx + VPN Direct overlays)
        │
        ▼
Libbox.xcframework  (profile: vpn_direct_ios / Darwin tags)
        │
        ▼
Library (VPNDirect parsers/builders) → ExtensionProvider → NEPacketTunnel
```

## Apple targets

| Component | Path |
|-----------|------|
| iOS app | `SFI/` |
| macOS app | `SFM/`, `SFM.System/` |
| tvOS app | `SFT/` |
| Shared UI | `ApplicationLibrary/` |
| Shared networking / DB | `Library/` |
| Packet tunnel | `Extension/` → `Library/Network/ExtensionProvider.swift` |

Apps embed Network Extension; **Libbox** is linked into Library and used by the extension process.

## Subscription / import pipeline (Swift)

```text
raw bytes / file / paste / QR / URL
  → VPNDirectContentDetector
       (sing-box JSON · Xray · Clash YAML · WG/AWG conf · Mieru ·
        OpenVPN · OpenConnect · Tailscale · MASQUE CONNECT-UDP ·
        URI list · base64)
  → format adapters / VPNDirectParserRegistry
  → NormalizedSubscription → NormalizedLocation[] → NormalizedNode[]
  → UniversalOutboundBuilder (+ capability gates)
  → SingBoxGraphBuilder
       (proxy leaves → outbounds; WG/AWG/OpenVPN/OpenConnect/Tailscale → endpoints)
  → VPNDirectConfigValidator / LibboxCheckConfig
```

Remnawave/Happ XRAY_JSON topology (country locations, global Auto, per-profile dedupe, `dialerProxy`→`detour`) is implemented in the production graph builder.

## Extension rules

- Prefer new packages over editing upstream files
- Feature flags via build tags (`with_xhttp`, `with_awg`, `with_mieru`, `with_openvpn`, `with_openconnect`, `with_tailscale`, `with_quic`, …)
- Rebase onto upstream tags; never long-lived merge drift
- Document every imported feature in [`DONORS.md`](DONORS.md)
- Capabilities must match registered outbounds/endpoints (fail-closed)

## Capability Registry

Core reports what the **current binary** supports. Swift builders and UI must query capabilities instead of hardcoding stock-Libbox limitations.

- Go: `core/overlays/libbox/vpndirect_*.go` (applied at Libbox build)
- Sidecar stamp: `Libbox.xcframework/VPNDirectCore.version` from `scripts/build_libbox.sh`
- Swift: `Library/Shared/VPNDirectCoreCapabilities.swift`
- Fail-closed: unsupported features throw `unsupportedFeature` (no silent XHTTP→HTTPUpgrade, no silent CONNECT-UDP without capability)

## Parser / builder layer

- Under `Library/Service/VPNDirect/`
- Protocol / transport / security as extensible string IDs
- Prefer attributes + `UniversalOutboundBuilder`; pre-built `outbound`/`endpoint` dicts remain for tunnel imports (OpenVPN, Tailscale, CONNECT-UDP)
- Versioned strings for AWG (`"3.1"`), not closed enums

## Platform

Apple NetworkExtension integration stays in this repository. Do not fork ExtensionProvider unless Libbox API requires it.

## Status vocabulary

See [`PROTOCOL_MATRIX.md`](PROTOCOL_MATRIX.md). `parser+runtime` ≠ `tested`. Device tunnel/handshake remains EXTERNAL until interactive VPN permission + battle keys.

## Update / rebase

```text
cd core/sing-box
git fetch upstream
git rebase upstream/<tag>   # then re-apply // lx seams if needed
```

See [`BUILDING.md`](BUILDING.md) and [`DONORS.md`](DONORS.md).
