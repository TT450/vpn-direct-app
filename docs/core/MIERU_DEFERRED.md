# Mieru (Phase K) — port status

## Status

**DONE for Core registration (v1.0.6+).** `protocol/mieru` + `option/mieru.go` live under `core/overlays/sing-box/` and are applied onto the stock `sing-box-lx` pin by `scripts/apply_singbox_overlays.sh` (via bootstrap / `build_libbox.sh`) behind `with_mieru`. Tags enabled in `scripts/tags/vpn_direct_*.tags`. CapabilityJSON `mieru=true` when Libbox is rebuilt with those tags.

**Interop:** still `planned` until live mita evidence is committed under `interop/mieru/evidence/`.

Donor: [enfein/mieru](https://github.com/enfein/mieru) / [enfein/mbox](https://github.com/enfein/mbox).

## Checklist

- [x] Libbox baseline builds in CI (XHTTP/AWG/MASQUE)
- [ ] Measure NE RSS with idle_suspend on mid-tier iPhone (device evidence)
- [x] Port `protocol/mieru` + option/registry behind `with_mieru` via `core/overlays/sing-box` (stock pin + apply)
- [x] Call real Register; capability true only with tag + registration
- [x] Add `with_mieru` to tags after compile/`sing-box check` green
- [x] Fixtures under `tests/fixtures/regression/mieru/`
- [x] Swift builder aligned with mbox JSON (`transport`, `username`, `password`, `multiplexing`, `traffic_pattern`)
- [x] Flip matrix Core column + status to `parser+runtime` (Interop planned)
- [ ] Interop TCP / UDP / Low Entropy evidence under `interop/mieru/evidence/`

## Runtime JSON shape

```json
{
  "type": "mieru",
  "tag": "mieru-out",
  "server": "host",
  "server_port": 8964,
  "transport": "TCP",
  "username": "user",
  "password": "pass",
  "multiplexing": "MULTIPLEXING_HIGH",
  "traffic_pattern": "48"
}
```
