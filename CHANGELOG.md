# Changelog

All notable changes to VPN Direct (Apple client) are documented here.

## [1.0.6.1] — 2026-09-07

### Core shipping fix

- Mieru protocol sources live in `core/overlays/sing-box/` and are applied onto the public `sing-box-lx` pin (`v1.14.0-lx.35`) by `scripts/apply_singbox_overlays.sh`
- Submodule points at fetchable `Leadaxe/sing-box-lx` again (no private fork push required)
- `bootstrap_core.sh` / `build_libbox.sh` / ABI & production checks invoke overlay apply

## [1.0.6] — 2026-09-07

### Battle-key qualification ready

- Mieru Core outbound/inbound behind `with_mieru`; Swift builder aligned to mbox JSON
- Clash nested Reality/WS/gRPC/plugin opts; detector schemes for naive/shadowtls/http-proxy
- Executable `check_parser_execution.sh` + panic-boundary doc; interop env templates
- Matrix/docs honest: `parser+runtime` / qualification-ready — not fake `tested`

## [1.0.5] — 2026-09-07

### What's New

See [`WHATS_NEW.md`](WHATS_NEW.md).

#### Universal import + honesty gate
- Content detector; multi-scheme URI parsers; Clash YAML; Xray multi-proto leaves
- Validator / redaction; `check_production_ready.sh`; `protocol-matrix.json`
- Docs: README / Architecture / Matrix / Build / Contribute refreshed for post-harvest state

## [1.0.4] — 2026-09-07

### What's New

TheTochka Compatibility Harvest P0: NormalizedSubscription / Location, HY2, Remnawave balancers/Auto, per-profile dedupe, dialerProxy→detour.

## [1.0.3] — 2026-09-07

Happ-first subscription UA, Keychain HWID migration, CI ExtensionProfile deinit fix.

## [1.0.2] — 2026-09-07

GitHub Core polish + capability/NormalizedNode skeleton tranche.

## [1.0.1] — 2026-09-06

Core 0.1 hardening baseline (no silent XHTTP downgrade, fail-closed capabilities).

## [1.0.0] — 2026-09-06

- Initial public GPLv3 source offer for VPN Direct (Apple)
