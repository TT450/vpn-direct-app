# Changelog

All notable changes to VPN Direct (Apple client) are documented here.

## [1.0.3] — 2026-09-07

### What's New

See [`WHATS_NEW.md`](WHATS_NEW.md).

#### Subscription compatibility (Happ / Remnawave)
- `SubscriptionClientIdentity`: Happ UA always first; VPN Direct UAs only as fallback
- HWID migrated to Keychain with UserDefaults legacy import (no slot burn on update)
- `HTTPClient` remains VPN Direct identity (not Happ)
- `EndpointValidator` + TheTochka harvest doc for HY2/balancers next

#### CI
- Fix `ExtensionProfile` deinit for Xcode 16.4 Actions runners

## [1.0.2] — 2026-09-07

### What's New

See release notes history; GitHub Core polish + capability/NormalizedNode tranche.

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

#### Core 0.1 Hardening Baseline (correctness)
- No silent XHTTP → HTTPUpgrade downgrade
- Fail-closed Capability Registry + CapabilityJSON ABI
- AWG multi-peer / AWG3 parse; no `_vpndirect_*` runtime keys

#### Build / CI
- Pin sagernet gomobile; core-baseline workflow; check-abi / check-fixtures

## [1.0.0] — 2026-09-06

- Initial public GPLv3 source offer for VPN Direct (Apple)
