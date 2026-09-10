# Marzneshin

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/marzneshin/marzneshin |
| Docs | https://docs.marzneshin.org |
| Basic install | https://docs.marzneshin.org/docs/getting-started/basic-install/ |
| Install script | `sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install` |
| License | AGPL-3.0 (unlike Marzban — care if copying code) |
| Pin note | Pin release tag; marznode version must match panel for multi-backend labs. |
| last_checked | 2026-09-07 |

## Core / backend

Marzban evolution with **multi-backend**: Xray-core **and** Hysteria2. One user subscription may mix nodes from different backends — parsers must not assume every line is Xray-derived.

## Subscription formats

V2rayNG / OneClick / Nekoray / Clash / Clash Meta compatible. Mixed URI lists (e.g. `vless://` + `hysteria2://`) are the critical fixture shape.

## Headers / HWID / UA

Expect `Subscription-Userinfo` and update-interval style headers similar to Marzban. Confirm format selection via UA/path in lab.

## Topology notes

Do not collapse HY2 nodes into VLESS adapters. Tag / remark may indicate backend; prefer scheme-based detection (`hysteria2://`) over remark heuristics.

## API notes (lab only)

Admin CLI: `marzneshin cli admin create --sudo`. Dashboard default `http://localhost:8000/dashboard`. Use API/scripts under `interop/panels/marzneshin/` for export only.

## Fixtures

`tests/fixtures/panels/marzneshin/` — `mixed_xray_hy2.txt`, `headers.json`.

## Status

`researched` — fixtures present; not `tested`.
