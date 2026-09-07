# Marzban

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/Gozargah/Marzban |
| Docs | https://gozargah.github.io/marzban/en/docs/installation |
| Scripts | https://github.com/Gozargah/Marzban-scripts |
| Node | Marzban-node — https://gozargah.github.io/marzban/en/docs/marzban-node |
| Install | `sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install` |
| Pin note | Prefer tagged release on Gozargah/Marzban; project partially frozen / succession to PasarGuard & Marzneshin — pin SHA or tag for lab reproducibility. |
| last_checked | 2026-09-07 |

## Core / backend

Python (FastAPI) + React over **Xray-core only**. Protocols: VMess, VLESS, Trojan, Shadowsocks. No native Hysteria2/TUIC on stock Marzban.

## Subscription formats

Highly multi-client: URI list, Clash / Clash Meta, sing-box JSON, V2rayNG-compatible exports. Use Marzban as a **reference** subscription shape when validating parsers.

## Headers / HWID / UA

Common: `Subscription-Userinfo` (upload/download/total/expire), `Profile-Update-Interval`. Client UA may select format (Clash vs sing-box vs links) depending on template settings.

## Topology notes

Supports Marzban-node for distributed ingress. Subscription aggregates hosts/inbounds for the user. No Remnawave Response Rules matrix.

## API notes (lab only)

REST API with Swagger/OpenAPI at `/docs` on the panel. Dashboard default `:8000/dashboard/`. Create sudo admin via `marzban-cli`. Lab: create user → copy subscription URL → export body to fixtures.

## Fixtures

`tests/fixtures/panels/marzban/` — `uri_list.txt`, `clash.yaml`, `singbox.json`, `headers.json`.

## Status

`researched` — fixtures present; not `tested`.
