# wg-easy

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/wg-easy/wg-easy |
| Docs | https://wg-easy.github.io/wg-easy/latest |
| Compose | https://github.com/wg-easy/wg-easy/blob/master/docker-compose.yml |
| Image | `ghcr.io/wg-easy/wg-easy` (v15+ recommended); old `weejewel/wg-easy` obsolete |
| Pin note | Org moved from WeeJeWel → wg-easy; pin image tag (e.g. `:15`). |
| last_checked | 2026-09-07 |

## Core / backend

Web UI for **plain WireGuard** (no AmneziaWG obfuscation). Useful baseline vs AmneziaWG configs (same `PrivateKey`/`PublicKey`/`Endpoint`/`AllowedIPs` fields; AWG adds `Jc`/`Jmin`/`Jmax`/`S1`/`S2`/`H1`–`H4`).

## Subscription formats

Not a multi-protocol subscription panel — exports classic `.conf` peer files and QR codes. Optional one-time download links.

## Headers / HWID / UA

N/A for WireGuard conf download (browser session / one-time link). No `subscription-userinfo` model.

## Topology notes

Single WG interface, multiple peers. Prometheus metrics, 2FA, CIDR pool options in modern versions.

## API notes (lab only)

Docker env: `WG_HOST`, `PASSWORD`, ports `51820/udp` + `51821/tcp` UI. Export peer `.conf` into fixtures.

## Fixtures

`tests/fixtures/panels/wg-easy/` — `wireguard_peer.conf`, `headers.json` (minimal / N/A).

## Status

`researched` — WG baseline fixtures; VPN Direct has WG conf/URI parsers. Not `tested` as a panel product claim.
