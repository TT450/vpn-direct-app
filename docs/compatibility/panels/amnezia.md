# Amnezia

## Pins

| Item | Value |
| --- | --- |
| Client | https://github.com/amnezia-vpn/amnezia-client |
| Site / docs | https://amnezia.org — https://docs.amnezia.org |
| amneziawg-go | https://github.com/amnezia-vpn/amneziawg-go |
| Community AWG UI | https://github.com/spcfox/amnezia-wg-easy |
| Community compose | https://github.com/metya/AmneziaWG-Docker-Compose |
| Installer (systemd) | https://github.com/bivlked/amneziawg-installer |
| Pin note | Official path is client-driven Docker deploy over SSH — pin client release + container images it pulls. For AWG field semantics, pin amneziawg-go commit. |
| last_checked | 2026-09-07 |

## Core / backend

Not a classic multi-tenant panel: desktop/mobile client deploys protocols (OpenVPN, WireGuard, IKEv2, Cloak, Shadowsocks, **AmneziaWG**, XRay) onto a VPS. Lab alternatives: `amnezia-wg-easy` web UI or systemd installer for AWG-only.

## Subscription formats

AmneziaWG `.conf` with obfuscation fields; AWG URI schemes where used. Classic WG conf is a subset (missing Jc/J* / H*).

## Headers / HWID / UA

N/A for conf export. Device identity is Amnezia client–side, not Remnawave HWID headers.

## Topology notes

Obfuscation fields `Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1`–`H4` generated at server/user creation. Human docs are thin — `amneziawg-go` `device/` is the field source of truth. VPN Direct Core: `with_awg`; AWG3.1 catalog still expanding.

## API notes (lab only)

Prefer `amnezia-wg-easy` Docker for reproducible conf export without reverse-engineering the closed deploy path. Official client remains the production deploy path.

## Fixtures

`tests/fixtures/panels/amnezia/` — `awg2_sample.conf` (Jc/Jmin/Jmax), headers stub.

## Status

`partial` / `researched` — AWG conf/URI + Core runtime exist; full field catalog + device evidence incomplete. Not `tested` as product-complete Amnezia parity.
