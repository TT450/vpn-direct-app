# What's New — VPN Direct 1.0.2

Release date: 2026-09-07  
Git tag: `v1.0.2`

This release hardens **capability correctness**, starts the **NormalizedNode** parser path, and refreshes the public GitHub presence to read like a serious Core/open-source project — not only an App Store description.

---

## App Store / short What's New

- Stronger VPN Direct Core honesty: capabilities come from Core JSON, no fake Mieru
- Safer imports: no silent protocol downgrades; clearer unsupported-feature errors
- Subscription path starts routing through NormalizedNode (VLESS adapter)
- Engineering docs, Protocol Matrix, and multilingual GitHub README refreshed
- CI gates for ABI / capability proofs tightened

---

## Core & capabilities

- Removed `with_mieru` from `vpn_direct_full` until a real Mieru runtime exists
- `supportsMieru` / CapabilityJSON `mieru` stay **false**; CI asserts this for default profiles
- Compile-time proofs for **MASQUE**, **VLESS encryption/PQ**, and **Hysteria2 gecko** (donor symbol references)
- Expanded **CapabilityJSON** (`protocols` / `transports` trees including VLESS transports + security)
- Swift `VPNDirectCoreCapabilities` **mirrors Core JSON** when ABI is compatible — no hardcoded “hysteria2 supported / fixed transports” invention
- Stock / incompatible ABI still fail-closed (custom features all false)

## Build / CI

- `scripts/build_libbox.sh`: resolve `GOMOBILE_SHA` for `github.com/sagernet/gomobile` (fallback `golang.org/x/mobile`)
- Mandatory AWG submodule init **fails hard** when `with_awg` is in the profile
- `make check-capability-proofs` + extended `check-abi` (mieru disabled in tags + CapabilityJSON)
- Core baseline workflow runs capability proofs

## Parser / subscriptions (Milestone 2 start)

- New `Library/Service/VPNDirect/`:
  - `NormalizedNode`
  - `VPNDirectParser` + diagnostics (`total/parsed/unsupported/malformed`)
  - `VLESSShareLinkParser` adapter
- `SubscriptionConfigBuilder` builds share-link configs through the parser registry (VLESS behavior preserved)

## Documentation & GitHub polish

- `docs/core/PRODUCTION_READINESS_AUDIT.md` — honest DONE/PARTIAL/MISSING vs real code
- `docs/core/VPN_DIRECT_PRODUCTION_PLAN.md` — 10 hardening milestones
- Updated `PROTOCOL_MATRIX.md` / `MIERU_DEFERRED.md`
- Premium English README + hero banner; Russian / Uzbek / Chinese READMEs matched to the same Core-first layout
- Added `ROADMAP.md`, `SUPPORT.md`, PR template, richer issue templates
- Docs index at `docs/README.md`

## Explicitly not claimed

- Full universal URI/Clash parsers (Milestone 3+)
- Mieru runtime
- Interop/device “production” status for XHTTP / AWG / MASQUE / PQ without evidence

---

See also: [`CHANGELOG.md`](CHANGELOG.md), [`docs/core/VPN_DIRECT_PRODUCTION_PLAN.md`](docs/core/VPN_DIRECT_PRODUCTION_PLAN.md).
