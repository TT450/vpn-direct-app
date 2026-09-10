# Interop lab — wg-easy

Repo: https://github.com/wg-easy/wg-easy  
Docs: https://wg-easy.github.io/wg-easy/latest  
Image: `ghcr.io/wg-easy/wg-easy:15` (old `weejewel/wg-easy` obsolete)  
Dossier: `docs/compatibility/panels/wg-easy.md`  
Fixtures: `tests/fixtures/panels/wg-easy/`

## Lab goals

Plain WireGuard baseline (no AmneziaWG obfuscation). Export peer `.conf` (+ optional QR). Compare field set vs Amnezia AWG fixtures (`Jc`/`J*`/`H*` absent here).

## Run

```bash
cp .env.example .env
# Set WG_HOST to a reachable host/IP before up
docker compose --profile lab up -d
./run.sh
```
