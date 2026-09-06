# Changelog

All notable changes to VPN Direct (Apple client) are documented here.

## [1.0.2] — 2026-09-07

### What's New

See [`WHATS_NEW.md`](WHATS_NEW.md) for the full release write-up (App Store short text + engineering detail).

#### Capability correctness
- Removed fake `with_mieru` from `vpn_direct_full`; CapabilityJSON / CI assert `mieru=false`
- Compile-time proofs for MASQUE, VLESS encryption/PQ, Hysteria2 gecko
- Expanded CapabilityJSON protocol/transport trees; Swift mirrors Core JSON when ABI OK

#### Parser skeleton
- `NormalizedNode` + `VPNDirectParser` + VLESS adapter
- Subscription share-link path routes through the parser registry

#### Build / CI
- Fix `GOMOBILE_SHA` detection for sagernet gomobile; hard-fail AWG submodule init
- `make check-capability-proofs`; core-baseline workflow extended

#### GitHub / docs
- Premium Core-first README (EN/RU/UZ/ZH) + hero banner
- Production audit + production plan docs; ROADMAP, SUPPORT, PR/issue templates

## [1.0.1] — 2026-09-06

### What's New

#### Branding
- New red VPN Direct app icon across iOS, macOS, widget, and README brand assets
- macOS `Icons/AppIcon.icns` regenerated from the new mark

#### Core 0.1 Hardening Baseline (correctness)
- **No silent XHTTP → HTTPUpgrade downgrade** — missing Core support now throws `unsupportedFeature`
- Subscription import surfaces unsupported features instead of quietly dropping XHTTP nodes
- **Fail-closed Capability Registry** — unproven XHTTP / AWG / MASQUE / VLESS encryption / gecko are `false` or empty
- Prefer versioned `VPNDirectCapabilityJSON` with ABI handshake (`VPN_DIRECT_CORE` magic + API v1)
- AWG versions and Hysteria2 obfuscations come from Core exports, not Swift hardcodes
- AWG `.conf` parser: **multi-peer**, full AWG3 field parse, honest `hasNoObfuscation`
- Removed `_vpndirect_*` keys from runtime sing-box JSON (metadata stays on the Swift model)

#### Build / reproducibility
- Pin **`github.com/sagernet/gomobile@v0.1.12`** (matches donor `go.mod`; no `@latest`)
- Libbox stamp now records `SING_BOX_SHA`, `GOMOBILE_SHA`, profile, and tags
- Tag profiles: `vpn_direct_ios`, `vpn_direct_ios_minimal`, `vpn_direct_full`

#### CI / docs / fixtures
- GitHub Actions workflow `core-baseline` (fixtures, ABI overlays, Libbox build, SFI compile)
- `make check-abi` + expanded `make check-fixtures`
- Protocol matrix: explicit **Support definition** for when a row may become `tested`

### Notes
- Interop / device “tested” status for XHTTP, AWG, MASQUE, PQ remains **planned** until real server + iPhone gates pass
- Mieru remains deferred

## [1.0.0] — 2026-09-06

- Initial public GPLv3 source offer for VPN Direct (Apple)
- Hiddify-style multilingual README and public App Store / Telegram links
