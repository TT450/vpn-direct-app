# VPN Direct Core release blocker ledger

Status meanings:

- `OPEN` — known work not implemented.
- `IMPLEMENTED_UNVERIFIED` — code changed, but required regression/build evidence is not complete.
- `VERIFIED` — implementation and evidence complete.
- `EXTERNAL_BLOCKED` — blocked only by a genuinely external dependency (for example, no paired physical device). Code/test work is never external-blocked.

## Current blockers

| ID | Status | Blocker | Evidence / next gate |
|---|---|---|---|
| REQ-GRAPH-NO-SILENT-DROP | IMPLEMENTED_UNVERIFIED | Graph previously used `catch { continue }` | Changed on `chatgpt-remediation`; needs parser/package + Core config regression run |
| REQ-GRAPH-NO-MULTI-URLTEST-COERCION | IMPLEMENTED_UNVERIFIED | `leafTags.count > 1` changed topology to urltest | Changed to strategy-driven behavior; needs topology tests |
| REQ-GRAPH-GLOBAL-AUTO-ROOTS | IMPLEMENTED_UNVERIFIED | Global Auto selected individual leaves/helpers | Changed to selectable location roots; needs topology tests |
| REQ-GRAPH-DETOUR-FORWARD-REF | IMPLEMENTED_UNVERIFIED | Single-node forward detours were order-dependent | Moved detour resolution to second pass; needs forward-reference fixture |
| REQ-GRAPH-MISSING-DETOUR-FAIL | IMPLEMENTED_UNVERIFIED | Missing target silently disappeared | Now fails explicitly; needs malformed topology fixture |
| REQ-CONFIG-MIGRATE-THEN-CHECK | IMPLEMENTED_UNVERIFIED | Pre-migration JSON was checked instead of exact returned JSON | Changed graph order to migrate→check(final); needs regression/build evidence |
| REQ-GRAPH-STABLE-ID | OPEN | Display name is still used for detour identity | Introduce stable scoped node IDs and duplicate-name fixture |
| REQ-GRAPH-ENDPOINTS | OPEN | Graph still emits only `outbounds[]` | Add exact pinned Core endpoint collection and reference semantics |
| REQ-WG-ENDPOINT-ONLY | OPEN | Production WG/AWG path emits removed legacy outbound shape | Refactor to pinned endpoint schema |
| REQ-WG-MULTI-PEER | OPEN | Adapter keeps/normalizes only first peer in current production path | Typed interface + peers[] model |
| REQ-AWG-FULL-FIELDS | OPEN | Advanced AWG fields lost between parser/model/builder | Preserve exact pinned donor fields |
| REQ-WG-NO-TEST-REWRITE | OPEN | Battle/test path rewrites WG separately | Remove test-only rewrite after production endpoint path exists |
| REQ-EXTENSION-FAIL-CLOSED | OPEN | Tunnel startup has best-effort migration fallback | Enforce migrate→check→start exact config |
| REQ-NORMALIZED-TYPED-VALUES | OPEN | Connection-critical values still pass through `[String:String]` | Typed shared/protocol models |
| REQ-LEGACY-OUTBOUND-REMOVE | OPEN | Prebuilt `NormalizedNode.outbound` bypasses current validation | Inventory writers and migrate them |
| REQ-HY2-NO-SOURCE-REPARSE | OPEN | HY/HY2 builder reparses `node.source` | Build only from normalized typed state |
| REQ-MASQUE-SEPARATE-PROFILES | OPEN | Generic MASQUE and WARP are conflated/defaulted | Separate standard/cloudflare normalized profiles |
| REQ-MIERU-EXACT-TRANSPORT | OPEN | Missing Mieru transport silently becomes TCP | Exact donor schema + typed validation |
| REQ-SSH-NO-ROOT-DEFAULT | OPEN | Missing SSH user becomes `root` | Exact schema-driven required/default handling |
| REQ-XHTTP-TYPED-FIELDS | OPEN | Advanced XHTTP numeric/object fields emitted as strings | Exact pinned XHTTP types + golden assertions |
| REQ-UNKNOWN-TRANSPORT-FAIL | OPEN | Unknown explicit transport can disappear into default behavior | Protocol-specific transport validator |
| REQ-PANELS-EXHAUSTIVE | OPEN | Panel×format×protocol×field coverage incomplete | Source-derived exhaustive producer map/fixtures |
| REQ-CONTENT-STRUCTURAL-DETECTION | OPEN | Detector relies on preview heuristics and base64 URI condition | Structural detection + decoded-body re-detection |
| REQ-HTTP-FIRST-REQUEST-PRIVACY | OPEN | Happ-first request can disclose HWID to arbitrary host | Trust/negotiation policy |
| REQ-HTTP-ORIGIN-REDIRECT | OPEN | Redirect policy compares host rather than full origin | Scheme+host+effective-port policy and sensitive header registry |
| REQ-HTTP-STREAM-CAP | OPEN | Response body cap enforced after full body materialization | Streaming hard cap |
| REQ-HTTP-TYPED-ERRORS | OPEN | 4xx/451 panel body/headers lost as generic NSError | Typed bounded HTTP response error |
| REQ-HWID-DURABLE-KEYCHAIN | OPEN | Delete-before-add can lose stable identity | Update-first persistence state machine |
| REQ-BUILD-EXACT-PIN | OPEN | Prepare/apply can build from wrong donor HEAD | Exact pin checkout/proof before overlays |
| REQ-BUILD-OVERLAY-MANIFEST | OPEN | Verify path covers too little | Mandatory feature/overlay manifest |
| REQ-BUILD-NO-GO-GET-REPAIR | OPEN | Prepare can mutate dependency graph | Fail closed on missing pinned deps |
| REQ-BUILD-FRESH-LIBBOX | OPEN | Stale root Libbox can be selected | Isolate old artifact and verify invocation provenance |
| REQ-BUILD-EXACT-SLICES | OPEN | Platform family check can mask missing simulator/device slice | Per-requested-slice/architecture validation |
| REQ-BUILD-TOOLCHAIN-POLICY | OPEN | Go pin not enforced; `gomobile init || true` remains | Enforce documented toolchain policy |
| REQ-FIELD-COVERAGE | OPEN | Known-field support not yet mechanically traced end-to-end | Build field coverage manifest/checker |
| REQ-PRODUCTION-PATH-TESTS | OPEN | Battle and production paths are not yet identical | Remove all test-only schema transformations |
| REQ-IOS-BUILD | OPEN | Full clean iOS build pending remediation | Build after Core/Libbox passes |
| REQ-PHYSICAL-IPHONE | OPEN | Device gate pending | Attempt only when local paired/signing environment exists |
| REQ-FINAL-HEAD-REAUDIT | OPEN | Final audit must happen after last implementation change | Mandatory final pass |

## Current branch implementation notes

First production fix commit on this branch changed `SingBoxGraphBuilder` to:

- fail instead of silently dropping builder errors;
- use strategy-driven location behavior rather than endpoint-count-driven urltest coercion;
- resolve detours after all nodes receive tags;
- fail on missing detour targets;
- use semantic location roots for Global Auto;
- migrate before validating the exact returned config;
- stop labeling raw share-link nodes as countries.

These remain `IMPLEMENTED_UNVERIFIED` until the required regression/Core build evidence is collected.
