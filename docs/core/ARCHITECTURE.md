# VPN Direct Core architecture

## Strategy

Upstream **sing-box** remains the foundation. VPN Direct Core is a **thin fork** (starting from [sing-box-lx](https://github.com/Leadaxe/sing-box-lx)): extra features live in new files / build tags; upstream files touched only at marked seams.

```text
SagerNet/sing-box
        │
        ▼
core/sing-box (submodule: sing-box-lx + VPN Direct overlays)
        │
        ▼
Libbox.xcframework  (profile: vpn_direct_ios)
        │
        ▼
Library (VPNDirect parsers/builders) → ExtensionProvider → NEPacketTunnel
```

## Subscription / import pipeline (Swift)

```text
raw bytes
  → VPNDirectContentDetector   (JSON / Xray / Clash YAML / WG conf / Mieru / URI / base64)
  → format adapters / VPNDirectParserRegistry
  → NormalizedSubscription → NormalizedLocation[] → NormalizedNode[]
  → UniversalOutboundBuilder (+ capability gates)
  → SingBoxGraphBuilder (selector / location urltest / global auto)
  → VPNDirectConfigValidator / LibboxCheckConfig
```

Remnawave/Happ XRAY_JSON topology (country locations, global Auto, per-profile dedupe, `dialerProxy`→`detour`) is covered by TheTochka Compatibility Harvest P0 — see [`THETOCHKA_COMPATIBILITY_HARVEST.md`](THETOCHKA_COMPATIBILITY_HARVEST.md).

## Extension rules

- Prefer new packages over editing upstream files
- Feature flags via build tags (`with_xhttp`, `with_awg`, `with_mieru`, …)
- Rebase onto upstream tags; never long-lived merge drift
- Document every imported feature in `DONORS.md`
- Never enable `supportsMieru` / `with_mieru` until an outbound is registered (see [`MIERU_DEFERRED.md`](MIERU_DEFERRED.md))

## Capability Registry

Core reports what the **current binary** supports. Swift builders and UI must query capabilities instead of hardcoding stock-Libbox limitations.

- Go: `experimental/libbox/vpndirect_*.go` (overlays in `core/overlays/libbox/`, applied at build time)
- Sidecar stamp: `Libbox.xcframework/VPNDirectCore.version` written by `scripts/build_libbox.sh`
- Swift: `Library/Shared/VPNDirectCoreCapabilities.swift` — single source for builders
- Fail-closed: unsupported features throw `unsupportedFeature` (no silent XHTTP→HTTPUpgrade)

## Parser / builder layer (Swift)

- Under `Library/Service/VPNDirect/`
- Protocol / transport / security / obfuscation as extensible string IDs
- Prefer attributes + `UniversalOutboundBuilder` over stuffing pre-built `outbound` dicts long-term
- Versioned strings for AWG (`"3.1"`), not closed enums

## Platform

Apple NetworkExtension integration stays in this repository. Do not fork ExtensionProvider unless Libbox API requires it.

## Out of scope (Core 1.x)

MASQUE CONNECT-UDP, Tailscale, OpenVPN/OpenConnect — see Protocol Matrix `out_of_scope`.

## Update / rebase

```text
cd core/sing-box
git fetch upstream
git rebase upstream/<tag>   # then re-apply // lx seams if needed
```

See `BUILDING.md` and `DONORS.md`.
