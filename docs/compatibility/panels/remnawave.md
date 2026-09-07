# Remnawave

## Pins

| Item | Value |
| --- | --- |
| Org | https://github.com/remnawave |
| Panel docs | https://docs.rw/ |
| HWID | https://docs.rw/features/hwid-device-limit/ |
| Response Rules | https://docs.rw/learn-en/routing-rules/ |
| backend-contract | `@remnawave/backend-contract@3.4.5` (Response Rules TypeScript types) |
| Pin note | Prefer release tag from remnawave panel releases; contract package pin above for schema. SHA floats with panel deploy. |
| last_checked | 2026-09-07 |

## Core / backend

Xray-oriented control plane: Nodes, Hosts, Config Profiles, Subscription Templates, HWID Inspector, SRH Inspector, Response Rules. Subscription body shape is selected per request by Response Rules (UA / path / custom matchers), not a single fixed format.

## Subscription formats

| Type | Body |
| --- | --- |
| `XRAY_JSON` | JSON array of profiles (`remarks`, `outbounds`, optional `routing.balancers`) |
| `XRAY_BASE64` | Base64 of URI list (typically VLESS/VMess/Trojan/SS lines) |
| `MIHOMO` / `STASH` / `CLASH` | Clash-family YAML (proxies + optional groups) |
| `SINGBOX` | sing-box JSON |
| `BROWSER` | HTML / browser landing (not a VPN import) |
| `BLOCK` | Explicit block response |
| `STATUS_CODE_404` | HTTP 404 |
| `STATUS_CODE_451` | HTTP 451 (legal/unavailable) |
| `SOCKET_DROP` | Connection drop (no useful body) |

**Response Rules types (contract):** `BROWSER` `BLOCK` `STATUS_CODE_404` `STATUS_CODE_451` `SOCKET_DROP` `XRAY_JSON` `XRAY_BASE64` `MIHOMO` `STASH` `CLASH` `SINGBOX`.

## Headers / HWID / UA

**Request (when HWID limit enabled):** Happ-style UA; `x-hwid` required (404 if missing). Optional device OS / model / locale headers.

**HWID regex (v3+):** `/^[a-zA-Z0-9=-]{10,64}$/`

**Response headers (observed / documented):** `x-hwid-active`, `x-hwid-not-supported`, `x-hwid-max-devices-reached`, `x-hwid-limit` (and related counters), plus custom headers via `responseModifications` (e.g. `x-provider-id`). Traffic/profile headers may also appear depending on template.

## Topology notes

- Country location profiles + global **Auto** (urltest / balancer semantics).
- Multiple leaf outbounds can share the same backend endpoint under different remarks.
- Cascade: `streamSettings.sockopt.dialerProxy` → Core `detour`.
- Prefer HY2 inside a location when present (TheTochka harvest P0).
- Per-profile dedupe of identical leaf tags.

## API notes (lab only)

Use panel admin / backend API for create-user and subscription URL export in `interop/panels/remnawave/`. Do **not** call admin APIs from the iOS runtime. Lab scripts should capture response headers + body into `tests/fixtures/panels/remnawave/` and `evidence/`.

## Unknown fields policy

Unmapped `streamSettings` / `settings` keys → `rawExtensions`; connection-critical unknowns fail closed (see `CompatibilityFieldPolicy`).

## Fixtures

`tests/fixtures/panels/remnawave/` — headers, XRAY_JSON locations, XRAY_BASE64, Clash sample, unknown-critical, HWID blocked headers.

## Status

`researched` + fixtures present — **not** `tested` (no interop+device evidence yet).
