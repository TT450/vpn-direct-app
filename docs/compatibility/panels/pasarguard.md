# PasarGuard

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/PasarGuard/panel |
| Scripts | https://github.com/PasarGuard/scripts |
| Install | `sudo bash -c "$(curl -fsSL https://github.com/PasarGuard/scripts/raw/main/pasarguard.sh)" @ install --database timescaledb` |
| Pin note | Young/active project — pin release from https://github.com/PasarGuard/panel/releases; API may shift between versions. |
| last_checked | 2026-09-07 |

## Core / backend

Marzban succession panel supporting **Xray-core and WireGuard** in one control plane. Recommended DB: **TimescaleDB** (PostgreSQL time-series); MySQL also supported via install flag.

## Subscription formats

URI list may include `vless://` / other Xray schemes **and** `wireguard://` or `.conf` WireGuard peer snippets. Tags/forms separate WireGuard vs Xray cores in the editor (auto-generated tags/ports).

## Headers / HWID / UA

Claims HWID / device limits — verify against pinned release. Expect `Subscription-Userinfo`-style traffic headers when enabled. Capture live headers into fixtures before fingerprinting.

## Topology notes

Mixed Xray + WG in one subscription is the differentiator vs stock Marzban. Parsers must route WG lines to WireGuard/AWG path, not VLESS.

## API notes (lab only)

After install: `pasarguard cli generate-temp-key` → owner bootstrap on login page. Prefer documented API over raw DB (TimescaleDB differs from Marzban’s MySQL/SQLite).

## Fixtures

`tests/fixtures/panels/pasarguard/` — `uri_list.txt` (wireguard + vless), `headers.json`.

## Status

`researched` — fixtures present; not `tested`.
