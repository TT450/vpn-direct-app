# Interop lab — Amnezia

Not a classic multi-tenant panel. Official path is **client-driven** deploy over SSH
(Amnezia client pulls protocol containers onto a VPS).

Client: https://github.com/amnezia-vpn/amnezia-client  
Docs: https://docs.amnezia.org  
amneziawg-go: https://github.com/amnezia-vpn/amneziawg-go  
Community AWG UI: https://github.com/spcfox/amnezia-wg-easy  
Dossier: `docs/compatibility/panels/amnezia.md`  
Fixtures: `tests/fixtures/panels/amnezia/` (AWG conf)

## Lab goals

Export AmneziaWG `.conf` with obfuscation fields (`Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1`–`H4`). Prefer community `amnezia-wg-easy` for reproducible conf export; official client remains the production deploy path.

## Install notes (official)

1. Pin Amnezia client release in `VERSION`.
2. Deploy to a disposable VPS via the client (SSH).
3. Create AmneziaWG user; export `.conf` / share link into fixtures.
4. For AWG field semantics, pin `amneziawg-go` commit (see dossier).

## Optional Docker (community)

```bash
cp .env.example .env
docker compose --profile lab up -d
./run.sh
```

Compose uses a community image stub — verify image/tag from spcfox/amnezia-wg-easy before lab.
