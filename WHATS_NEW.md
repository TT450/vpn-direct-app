# What's New — VPN Direct 1.0.9

Release date: 2026-09-07  
Git tag: `v1.0.9`

## App Store / short What's New

- WireGuard and AmneziaWG now use the modern Core endpoint model (multi-peer, AWG 2 / 3.x)
- Safer subscription import: no silent node drops; clearer unsupported/malformed diagnostics
- Privacy-minded subscription fetch (no HWID blast to arbitrary hosts; safer redirects)
- Broader panel/format fixtures and production Swift parser regression coverage
- Physical iPhone install/launch verified; connect still requires your VPN permission on device

## Engineering detail

- `SingBoxGraphBuilder` emits `endpoints` for WG/AWG; migrate→validate final JSON
- Xray/Clash topology honesty; Remnawave HTTP classification; 3x-ui mux/finalmask
- `scripts/prepare_core.sh` / `build_libbox.sh` fail-closed; field/plan coverage gates
- See `docs/core/RELEASE_BLOCKER_LEDGER.md` and `docs/device/IPHONE_INSTALL_2026-09-07.md`
