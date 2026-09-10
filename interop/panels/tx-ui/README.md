# Interop lab — tx-ui

Primary fork: https://github.com/AghayeCoder/tx-ui  
Alternate fork: https://github.com/Incognito-Coder/tx-ui  
Docker (Incognito image): `ghcr.io/incognitocoder/tx-ui:latest`  
Dossier: `docs/compatibility/panels/tx-ui.md`  
Fixtures: `tests/fixtures/panels/tx-ui/`

## Lab goals

Direct 3x-ui fork — format ≈ 3x-ui. Pin **both** install script URL and image tag. Export raw/base64, Xray JSON, Clash; capture subscription headers. Keep fixtures separate for fork drift.

## Run

```bash
cp .env.example .env
# Prefer AghayeCoder install.sh on a disposable VPS, or:
docker compose --profile lab up -d
./run.sh
```
