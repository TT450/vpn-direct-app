# Mieru (Phase K) — deferred

## Status

**Deferred for Core 0.1.** Libbox baseline from `sing-box-lx` (XHTTP / AWG / MASQUE / VLESS encryption) is the acceptance gate. Mieru from [enfein/mbox](https://github.com/enfein/mbox) is not merged into `core/sing-box` yet.

**Capability policy:** `with_mieru` is **not** present in `vpn_direct_ios.tags` or `vpn_direct_full.tags`. `VPNDirectSupportsMieru` / CapabilityJSON `mieru` stay `false` until a real runtime is registered.

## Why defer

1. mbox carries a separate portable package set (`protocol/mieru` + option/registry wiring); merging before an Apple `vpn_direct_ios` Libbox boots risks rebase noise on an already large lx tree.
2. Network Extension memory budget: extra protocol surface should land only after size/RAM of the lx Libbox is measured on device.
3. Capability surface already reserves `supportsMieru` / `with_mieru` (Go stubs + Swift gate) so UI/builders can stay unchanged when the tag appears.

## Unblock checklist

- [ ] `scripts/build_libbox.sh` produces a device-linked Libbox with XHTTP+AWG green
- [ ] Measure NE RSS with idle_suspend on a mid-tier iPhone
- [ ] Port only `protocol/mieru` + option/registry (+ tests) behind `with_mieru`
- [ ] Add `with_mieru` to `scripts/tags/vpn_direct_ios.tags` (and full) when size is acceptable
- [ ] Share-link / JSON fixtures under `tests/fixtures/regression/mieru/`
- [ ] Flip `PROTOCOL_MATRIX.md` Mieru row to **builder+core**
- [ ] CapabilityJSON `mieru=true` only after outbound registration proof

## Interim behavior

`VPNDirectCoreCapabilities.supportsMieru` is `false`. No Swift Mieru parser ships in 0.1. CI asserts profile tags and CapabilityJSON keep mieru disabled.
