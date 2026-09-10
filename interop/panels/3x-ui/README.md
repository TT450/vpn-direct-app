# Interop lab — 3x-ui

Repo: https://github.com/MHSanaei/3x-ui  
Dossier: `docs/compatibility/panels/3x-ui.md`  
Fixtures: `tests/fixtures/panels/3x-ui/`

## Lab goals

Enable `subEnable` (port 2096). Export raw/base64, Xray JSON, Clash path formats. Capture `Routing` / `Routing-Enable` headers.

## Run

```bash
cp .env.example .env
docker compose --profile lab up -d
./run.sh
```
