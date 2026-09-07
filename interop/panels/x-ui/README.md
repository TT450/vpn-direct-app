# Interop lab — x-ui

Repo: https://github.com/alireza0/x-ui  
Dossier: `docs/compatibility/panels/x-ui.md`  
Fixtures: `tests/fixtures/panels/x-ui/`

## Lab goals

Subscription format ≈ 3x-ui twin. Export raw/base64 URI list; capture Clash/V2RayNG-style headers. Diff against `tests/fixtures/panels/3x-ui/` — do not assume wire-identical headers.

## Run

```bash
cp .env.example .env
docker compose --profile lab up -d
./run.sh
```
