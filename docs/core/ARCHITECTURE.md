# VPN Direct Core architecture

## Strategy

Upstream **sing-box** remains the foundation. VPN Direct Core is a **thin fork** (starting from [sing-box-lx](https://github.com/Leadaxe/sing-box-lx)): extra features live in new files / build tags; upstream files touched only at marked seams.

```text
SagerNet/sing-box
        │
        ▼
core/sing-box (submodule: sing-box-lx + future VPN Direct patches)
        │
        ▼
Libbox.xcframework  (profile: vpn_direct_ios)
        │
        ▼
Library → ExtensionProvider → NEPacketTunnel
```

## Extension rules

- Prefer new packages over editing upstream files
- Feature flags via build tags (`with_xhttp`, `with_awg`, `with_mieru`, …)
- Rebase onto upstream tags; never long-lived merge drift
- Document every imported feature in `DONORS.md`

## Capability Registry

Core reports what the **current binary** supports. Swift builders and UI must query capabilities instead of hardcoding stock-Libbox limitations.

- Go: `experimental/libbox/vpndirect_*.go` (overlays in `core/overlays/libbox/`, applied at build time) export `VPNDirectSupportsXHTTP`, `VPNDirectBuildTagsCSV`, etc.
- Sidecar stamp: `Libbox.xcframework/VPNDirectCore.version` written by `scripts/build_libbox.sh`
- Swift: `Library/Shared/VPNDirectCoreCapabilities.swift` — single source for builders

## Parser / builder layer (Swift)

- Normalize provider formats → sing-box JSON understood by Libbox
- Protocol / transport / security / obfuscation as separable fields
- Versioned strings for AWG (`"3.1"`), not closed enums

## Platform

Apple NetworkExtension integration stays in this repository. Do not fork ExtensionProvider unless Libbox API requires it.

## Update / rebase

```text
cd core/sing-box
git fetch upstream
git rebase upstream/<tag>   # then re-apply // lx seams if needed
```

See `BUILDING.md` and `DONORS.md`.
