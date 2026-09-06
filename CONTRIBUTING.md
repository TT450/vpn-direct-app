# Contributing to VPN Direct

Thanks for helping improve the open source Apple client.

## Before you start

1. Read [`docs/core/ARCHITECTURE.md`](docs/core/ARCHITECTURE.md) — keep Network Extension lifecycle thin; prefer Core / builders / docs changes.
2. Do **not** commit secrets: `.p8`, `api_key.json`, provisioning profiles, real server credentials, or private keys.
3. Do **not** commit built `Libbox.xcframework` — use `scripts/build_libbox.sh`.
4. Do **not** claim Protocol Matrix `tested` without interop + device evidence.

## Development flow

```bash
./scripts/bootstrap_core.sh
make libbox          # when Core / Libbox changes
make check-fixtures
make check-production-ready
# Xcode: scheme SFI
```

## Pull requests

- Prefer small, reviewable PRs
- Include a short **why** in the description
- For protocol/builder changes, add or update fixtures under `tests/fixtures/regression/`
- Update `docs/core/PROTOCOL_MATRIX.md` **and** `core/protocol-matrix.json` when protocol status changes
- Keep capability fail-closed: no `with_mieru` / `supportsMieru=true` without a registered outbound

## Coding notes

- Swift parsers/builders live under `Library/Service/VPNDirect/`
- Go overlays for Libbox live in `core/overlays/libbox/` and are applied at build time
- Capability checks go through `VPNDirectCoreCapabilities` — avoid hardcoding “stock Libbox” assumptions
- Prefer `NormalizedNode` attributes + `UniversalOutboundBuilder` over long-lived pre-built `outbound` dicts

## License

By contributing, you agree that your contributions are licensed under the **GNU GPL v3** (or later), consistent with this repository and upstream sing-box for Apple.
