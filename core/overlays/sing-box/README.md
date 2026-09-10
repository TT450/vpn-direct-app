# sing-box overlays (VPN Direct)

Protocol ports that must ship with the app **without** requiring push access to `Leadaxe/sing-box-lx`.

## Layout

- `include/`, `option/`, `protocol/`, `transport/` — new sources copied onto the checked-out pin
- `patches/mieru-stock.patch` — idempotent edits for Mieru (`constant/proxy.go`, `include/registry.go`, `go.mod`, `go.sum`)
- `patches/connect-udp-ssr-stock.patch` — CONNECT-UDP type/register + ShadowsocksR register + libbox tags (SSR, Tailscale, Mieru)

## Features covered

- Mieru inbound/outbound
- MASQUE CONNECT-UDP outbound (`masque-connect-udp`)
- ShadowsocksR outbound (`with_shadowsocksr` + `transport/clashssr`)

## Apply

```bash
scripts/apply_singbox_overlays.sh
```

Invoked automatically from `scripts/bootstrap_core.sh` and `scripts/build_libbox.sh` via `prepare_core.sh`.

Pin: `core/VERSION` → `SING_BOX_REV` (currently `v1.14.0-lx.35`).
