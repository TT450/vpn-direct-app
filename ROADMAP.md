# Roadmap

Public roadmap for VPN Direct (Apple client + VPN Direct Core). Status language matches [`docs/core/PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md) and [`docs/core/RELEASE_BLOCKER_LEDGER.md`](docs/core/RELEASE_BLOCKER_LEDGER.md).

## Shipped in 1.0.11 / 1.0.11.63

- [x] Home Screen / Lock Screen / Control Center widgets (VPN Direct)
- [x] In-widget VPN toggle without opening the app (build **63**)
- [x] Widget status labels **Включен** / **Включить** + live NE status
- [x] Connection mode **5G**; DirectUI import menu / ping polish
- [x] TestFlight **1.0.11 (63)** + Asc/`fastlane ios release` docs

## Shipped in 1.0.10

- [x] OpenVPN / OpenConnect / Tailscale file+JSON import → graph endpoints
- [x] MASQUE CONNECT-UDP Core outbound + Swift import (Libbox rebuild for device capability)
- [x] Docs refresh; obsolete Core 0.1 audit drafts removed

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
- [x] Mieru Core runtime registration behind `with_mieru` (v1.0.6)
- [x] Clash nested Reality/WS/gRPC/plugin opts + executable parser checks
- [x] Interop lab runnable templates (env battle-key injection)
- [x] Compatibility KB + P0 fail-closed unknown fields / panel HTTP metadata / panel-compatibility gate

## Next

- [ ] Rebuild Darwin Libbox with CONNECT-UDP capability + `with_tailscale` and qualify on device
- [ ] Deep Marzban / Hiddify / PasarGuard / s-ui fixtures + Response Rules corpus
- [ ] Full Clash YAML library evaluation
- [ ] XHTTP extra / CDN quirks
- [ ] NE RSS budget measurement with Mieru / Tailscale enabled (device evidence)
- [ ] Interop evidence per family (`interop/*/evidence/`)
- [ ] iPhone device qualification filled for Tier‑1 protocols
- [ ] Flip matrix rows to `tested` only with interop+device evidence

## Later

- [ ] Screenshots / architecture diagram assets for GitHub
- [ ] Ecosystem / “Used by” section when appropriate
- [ ] Optional thin-fork strategy for a dedicated Core remote

## Non-goals

SoftEther and other protocols not listed in [`PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md). OpenVPN / OpenConnect / Tailscale / CONNECT-UDP are **in scope** as of v1.0.10 (`parser+runtime`; device `tested` pending Libbox rebuild + evidence).
