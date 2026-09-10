# Libertea

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/VZiChoushaDui/Libertea |
| README / FAQ | https://github.com/VZiChoushaDui/Libertea/blob/master/README.md |
| Bootstrap | `curl -s https://raw.githubusercontent.com/VZiChoushaDui/Libertea/master/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh install` |
| Requirements | Ubuntu 20.04+/Debian 11+ (22.04 recommended), ≥1 GB RAM, domain on CDN (Cloudflare Full SSL typical) |
| Pin note | Pin bootstrap.sh commit / release; HAProxy owns 80/443. |
| last_checked | 2026-09-07 |

## Core / backend

Multi-protocol V2Ray stack (Trojan, Shadowsocks/v2ray, VLESS, VMess) with domain camouflage and **auto-failover groups**. Secondary/proxy servers via `init-proxy.sh`; cron `libertea-autoupdate-proxy.sh` for cascades.

## Subscription formats

Clash-oriented group exports are the distinctive shape: multiple proxy groups that may share the same conceptual server endpoint with failover ordering. URI lists also possible depending on export path.

## Headers / HWID / UA

Standard Clash subscription headers when serving Clash YAML. No Remnawave HWID model.

## Topology notes

**Group routing:** client tries group A, falls back to group B on failure — map to Core urltest/selector or documented Libertea semantics. Camouflage domain: HAProxy splits legit site vs VPN by SNI/protocol. Backup = copy `/root/libertea`.

## API notes (lab only)

No rich REST API like Marzban — configure via Libertea UI/files; export Clash subscription for fixtures. Lab notes in `interop/panels/libertea/`.

## Fixtures

`tests/fixtures/panels/libertea/` — `groups_clash.yaml` (two groups, shared endpoint concept), `headers.json`.

## Status

`researched` — fixtures present; not `tested`.
