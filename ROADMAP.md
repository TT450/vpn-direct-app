# Roadmap

Public roadmap for VPN Direct (Apple client + VPN Direct Core). Status language matches [`docs/core/PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md) and [`docs/core/VPN_DIRECT_PRODUCTION_PLAN.md`](docs/core/VPN_DIRECT_PRODUCTION_PLAN.md).

## Now (1.0.x)

- [x] Capability ABI + CapabilityJSON fail-closed
- [x] No silent XHTTP → HTTPUpgrade
- [x] Remove fake Mieru capability / tags until runtime exists
- [x] Compile-time proofs for MASQUE / VLESS encryption / gecko
- [x] NormalizedNode + VLESS adapter skeleton
- [x] Happ-first subscription identity + Keychain HWID
- [x] TheTochka harvest P0: HY2, Remnawave location urltest, global auto, per-profile dedupe, dialerProxy→detour
- [x] Core baseline CI green (fixtures + ABI + Libbox + SFI)
- [x] Content detector (JSON / YAML / conf / URI / base64) without destructive trim
- [x] Universal multi-scheme URI parsers (VMess, Trojan, SS, TUIC, AnyTLS, WG/AWG, SOCKS/HTTP/SSH, ShadowTLS, Naive)
- [x] Clash / Mihomo YAML import (proxies only)
- [x] Expanded regression fixtures + universal parser checks
- [x] `VPNDirectConfigValidator` + Core error model v2 + redacted logging
- [x] Interop lab scaffolds + iPhone qualification checklist
- [x] Machine-readable `core/protocol-matrix.json`
- [x] `scripts/check_production_ready.sh` release gate
- [ ] Mieru Core runtime registration behind `with_mieru` (Swift parse/fail-closed done; capability still false)

## Next

- [ ] Mieru protocol merge + RSS budget + capability true
- [ ] Interop evidence per family (`interop/*/evidence/`)
- [ ] iPhone device qualification filled for Tier‑1 protocols
- [ ] Flip matrix rows to `tested` only with interop+device evidence

## Later

- [ ] Screenshots / architecture diagram assets for GitHub
- [ ] Ecosystem / “Used by” section when appropriate
- [ ] Optional thin-fork strategy for a dedicated Core remote

## Non-goals / out of scope (Core 1.x)

OpenVPN / OpenConnect, SoftEther, MASQUE CONNECT-UDP, Tailscale — not claimed as product features. See matrix `out_of_scope` rows.
