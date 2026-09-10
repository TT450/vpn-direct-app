## Summary

<!-- 1–3 bullets: what and why -->

## Context

- Related issue / Protocol Matrix row (if any):
- Capability / Core impact: yes / no

## Test plan

- [ ] `make check-fixtures`
- [ ] `make check-abi` (and `make check-capability-proofs` if Core overlays changed)
- [ ] SFI / relevant scheme compiles
- [ ] No silent protocol fallback introduced
- [ ] Docs / Protocol Matrix updated when status changes

## Checklist

- [ ] No secrets, private keys, or real subscription URLs
- [ ] No backend / private API / ops (hosts, IPs, admin paths, `/api/v1` product routes, `DirectBackendAPI` / hooks, `VPNDirectPatch`, `mobile_api`)
- [ ] Fixtures added/updated for parser or capability changes
- [ ] `WHATS_NEW.md` / `CHANGELOG.md` updated if this is user-visible
