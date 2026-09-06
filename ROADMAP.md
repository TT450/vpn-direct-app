# Roadmap

Public roadmap for VPN Direct (Apple client + VPN Direct Core). Status language matches [`docs/core/PROTOCOL_MATRIX.md`](docs/core/PROTOCOL_MATRIX.md) and [`docs/core/VPN_DIRECT_PRODUCTION_PLAN.md`](docs/core/VPN_DIRECT_PRODUCTION_PLAN.md).

## Now (1.0.x)

- [x] Capability ABI + CapabilityJSON fail-closed
- [x] No silent XHTTP → HTTPUpgrade
- [x] Remove fake Mieru capability / tags until runtime exists
- [x] Compile-time proofs for MASQUE / VLESS encryption / gecko
- [x] NormalizedNode + VLESS adapter skeleton
- [x] Happ-first subscription identity + Keychain HWID
- [ ] Universal multi-scheme URI parsers (VMess, Trojan, SS, HY2, TUIC, …)
- [ ] TheTochka harvest: Hysteria/HY2, Remnawave balancers, location urltest, cascades
- [ ] Clash / Mihomo YAML import
- [ ] Expanded regression fixtures + `sing-box check` in CI

## Next

- [ ] `VPNDirectConfigValidator` + Core error model v2 + redacted logging
- [ ] Interop lab under `interop/` (Xray, Amnezia, Hysteria, …)
- [ ] iPhone device qualification matrix (RSS, reconnect, TCP/UDP/DNS)
- [ ] Machine-readable `core/protocol-matrix.json`
- [ ] `scripts/check_production_ready.sh` release gate

## Later

- [ ] Mieru behind `with_mieru` after memory-budget path
- [ ] Screenshots / architecture diagram assets for GitHub
- [ ] Ecosystem / “Used by” section when appropriate
- [ ] Optional thin-fork strategy for a dedicated Core remote

## Non-goals (near term)

OpenVPN / OpenConnect, SoftEther, CONNECT-UDP, claiming full Core “production complete” without interop + device evidence.
