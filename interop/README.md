# Interop lab

Canonical **protocol** reference labs: [`protocols/`](protocols/).

Panel labs remain under [`panels/`](panels/). Fixtures under `tests/fixtures/regression/` stay secret-free.

**Never** commit real battle keys. Inject via env (see each family `run.sh` / `.env.example`).

| Family | Canonical path | Status |
| --- | --- | --- |
| Xray | [`protocols/xray/`](protocols/xray/) | scaffold |
| Hysteria | [`protocols/hysteria/`](protocols/hysteria/) | scaffold |
| TUIC | [`protocols/tuic/`](protocols/tuic/) | scaffold |
| AnyTLS | [`protocols/anytls/`](protocols/anytls/) | scaffold |
| ShadowTLS | [`protocols/shadowtls/`](protocols/shadowtls/) | scaffold |
| Naive | [`protocols/naive/`](protocols/naive/) | scaffold |
| WireGuard | [`protocols/wireguard/`](protocols/wireguard/) | scaffold |
| AmneziaWG | [`protocols/amneziawg/`](protocols/amneziawg/) | scaffold |
| MASQUE | [`protocols/masque/`](protocols/masque/) | scaffold |
| Mieru | [`protocols/mieru/`](protocols/mieru/) | scaffold |
| SOCKS / HTTP / SSH | [`protocols/socks/`](protocols/socks/) … | scaffold |

Legacy directories [`xray/`](xray/), [`hysteria/`](hysteria/), [`mieru/`](mieru/), [`amnezia/`](amnezia/)
point at `protocols/<name>` (amnezia → `amneziawg`).

Attach evidence under each `evidence/` before flipping PROTOCOL_MATRIX Interop / Status to `tested`.

Device checklist: [`docs/device/IPHONE_QUALIFICATION.md`](../docs/device/IPHONE_QUALIFICATION.md).
