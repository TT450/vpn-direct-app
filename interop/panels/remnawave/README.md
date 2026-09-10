# Interop lab — Remnawave

Docs: https://docs.rw/  
Dossier: `docs/compatibility/panels/remnawave.md`  
Fixtures: `tests/fixtures/panels/remnawave/`

## Lab goals

1. Spin panel + node (or use existing).
2. Create user with HWID limit enabled.
3. Export subscriptions for Response Rules types: `XRAY_JSON`, `XRAY_BASE64`, `CLASH`, `SINGBOX` (and sample `STATUS_CODE_404` / HWID block headers).
4. Copy sanitized bodies into fixtures; attach raw captures under `evidence/` (redact secrets).

## Run

```bash
cp .env.example .env
# fill PANEL_URL / ADMIN credentials
./run.sh
```

Do not mark panel `tested` without `evidence/` + device qualification.
