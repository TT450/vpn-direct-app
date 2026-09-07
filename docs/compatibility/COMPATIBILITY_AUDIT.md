# Compatibility Audit

Date: **2026-09-07**  
Scope: VPN Direct vs real panel / subscription / protocol ecosystems.

Legend: `DONE` | `PARTIAL` | `MISSING` | `BROKEN` | `UNPROVEN`

## First report (pre-change)

### Panels researched (sources pinned in PANEL_VERSION_MATRIX)

| Panel | Upstream | Status |
| --- | --- | --- |
| Remnawave | remnawave/panel + docs.rw + backend-contract | DONE (researched; harvest P0 + fixtures; not full Response Rules catalog) |
| 3x-ui | MHSanaei/3x-ui subscription.mdx + subController headers | DONE (researched; headers + fixtures) |
| x-ui | alireza0/x-ui | DONE (researched; twin of 3x-ui formats) |
| tx-ui | Incognito-Coder/tx-ui | DONE (researched; twin raw_links + headers) |
| Marzban | Gozargah/Marzban | DONE (researched; uri/clash/singbox fixtures) |
| Marzneshin | marzneshin/Marzneshin | DONE (researched; mixed vless+hy2) |
| PasarGuard | PasarGuard/panel | DONE (researched; vless+wireguard) |
| Hiddify Manager | hiddify/Hiddify-Manager | DONE (researched; base64/clash/userinfo) |
| Libertea | VZiChoushaDui/Libertea | DONE (researched; groups Clash) |
| s-ui | alireza0/s-ui | DONE (researched; sing-box JSON) |
| wg-easy | wg-easy | DONE (researched; peer.conf) |
| Amnezia | amnezia-vpn | DONE (researched; AWG2 sample; AWG partial in Core) |

### Subscription formats found in the wild

```text
URI list · base64 URI · XRAY_JSON (array/object) · XRAY_BASE64
Clash / Mihomo YAML · Stash · SINGBOX JSON
WG/AWG .conf · Mieru client JSON · Happ HTML browser page
```

Remnawave Response Rules `responseType` enum (backend-contract):  
`BROWSER | BLOCK | STATUS_CODE_404 | STATUS_CODE_451 | SOCKET_DROP | XRAY_JSON | XRAY_BASE64 | MIHOMO | STASH | CLASH | SINGBOX`

### New / under-handled fields vs current VPN Direct

| Area | Examples | Current behavior |
| --- | --- | --- |
| 3x-ui / Happ headers | `Announce`, `Support-Url`, `Profile-Web-Page-Url`, `Routing`, `Routing-Enable` | PARTIAL — title/userinfo/HWID only |
| Remnawave HWID | `x-hwid-not-supported`, provider id headers | PARTIAL |
| VLESS URI extras | XHTTP `extra`, `mode`, `xmux`, unknown query | BROKEN — silently ignored outside known set |
| Xray streamSettings | sockopt beyond dialerProxy, reality extras | PARTIAL — converter subset |
| Clash nested | full YAML, smux, packet-encoding | PARTIAL — indent subset |
| NormalizedNode | rawExtensions / fail-closed unknown | MISSING |
| Panel fingerprint | headers/body (not domain) | MISSING |

### Parser paths that lose data today

1. **`VLESSConfigBuilder`** — only reads allowlisted query keys; other query params discarded.
2. **`XrayJSONAdapter`** — `converted == nil` → `continue` (node dropped, no diagnostic); attributes mostly `xrayTag` only.
3. **`ClashYAMLAdapter`** — unknown nested keys may never enter attributes; unsupported proxy type throws (good) but partial maps lose depth.
4. **Share-link parsers** — mostly stash entire query into `attributes` (better); builders may still ignore unknown attrs without fail-closed.
5. **sing-box JSON** — migrate/validate path; unknown Core fields fail at LibboxCheck (good) but no panel-level classification.

### Dangerous assumptions

- “Remnawave supported” ≈ one Happ `XRAY_JSON` shape (locations + balancers) — **not** full Response Rules matrix.
- Happ UA always first — correct for Remnawave; other panels may need alternate Accept/path formats (3x-ui path-based formats).
- Ignoring unknown AWG/XHTTP/HY obfs fields would be handshake-breaking — must fail closed.

### P0 blockers

1. No `rawExtensions` + connection-critical unknown policy  
2. Incomplete subscription HTTP metadata capture  
3. Thin/no per-panel fixture corpus under `tests/fixtures/panels/`  
4. Xray convert failures silent  
5. No machine-readable `panel-compatibility.json` gate  

### Implementation order

See [COMPATIBILITY_IMPLEMENTATION_PLAN.md](COMPATIBILITY_IMPLEMENTATION_PLAN.md). P0 starts immediately after this audit.

## Block status (living)

| Block | Status | Notes |
| --- | --- | --- |
| Source research KB | DONE | 12 panel dossiers researched; deep API still open for some |
| Normalized extensions + fail-closed | → code | this tranche |
| Subscription HTTP | PARTIAL | Happ/HWID done; announce/routing/ETag next |
| Panel adapters (fingerprint) | MISSING → PARTIAL | CompatibilityProfile |
| Full Clash | PARTIAL | nested opts; no SPM YAML yet |
| Xray variants | PARTIAL | harvest P0; silent drop fix |
| Protocol edge cases | PARTIAL | XHTTP/AWG/HY |
| Mieru runtime | DONE | overlays + `with_mieru` (v1.0.6) |
| Panel fixtures | DONE | corpus seeded under `tests/fixtures/panels/*` |
| Protocol fixtures | PARTIAL | regression/ exists |
| API lab automation | MISSING | interop/panels scaffolds |
| Live panel lab | UNPROVEN | |
| Fuzz | PARTIAL | parser execution smoke |
| Device qualification | UNPROVEN | evidence schema ready; no device runs |
| Production gate panels | MISSING → PARTIAL | claims require fixtures |
