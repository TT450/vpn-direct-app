# sing-box overlays (VPN Direct)

Protocol ports that must ship with the app **without** requiring push access to `Leadaxe/sing-box-lx`.

## Layout

- `include/`, `option/`, `protocol/` — new sources copied onto the checked-out pin
- `patches/mieru-stock.patch` — idempotent edits to `constant/proxy.go`, `include/registry.go`, `go.mod`, `go.sum`

## Apply

```bash
scripts/apply_singbox_overlays.sh
```

Invoked automatically from `scripts/bootstrap_core.sh` and `scripts/build_libbox.sh`.

Pin: `core/VERSION` → `SING_BOX_REV` (currently `v1.14.0-lx.35`).
