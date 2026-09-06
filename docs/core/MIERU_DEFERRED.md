# Mieru (Phase K) — port status

## Status

**Swift side: DONE for this tranche.** `MieruConfigAdapter` parses client JSON → `NormalizedNode(protocolID: .mieru)`. Builder emits only when `VPNDirectCoreCapabilities.supportsMieru`.

**Core runtime: NOT REGISTERED.** `with_mieru` remains absent from `scripts/tags/vpn_direct_*.tags`. CapabilityJSON `mieru=false`.

Donor: [enfein/mieru](https://github.com/enfein/mieru) / [enfein/mbox](https://github.com/enfein/mbox) — pin a modern revision (Low Entropy 32/40/48/56) when merging.

## Unblock checklist

- [x] Libbox baseline builds in CI (XHTTP/AWG/MASQUE)
- [ ] Measure NE RSS with idle_suspend on mid-tier iPhone
- [ ] Port `protocol/mieru` + option/registry behind `with_mieru` into `core/sing-box`
- [ ] Call real Register; set capability true only after validate
- [ ] Add `with_mieru` to tags only after size budget OK
- [x] Fixtures under `tests/fixtures/regression/mieru/`
- [x] Swift fail-closed builder when capability false
- [ ] Flip matrix Core column + status after registration proof
- [ ] Interop TCP / UDP / Low Entropy evidence under `interop/mieru/evidence/`

## Interim behavior

Parse succeeds; graph build / outbound emit throws `unsupportedFeature(mieru)` until Core registers the outbound. Happ UA is never used for Mieru.
