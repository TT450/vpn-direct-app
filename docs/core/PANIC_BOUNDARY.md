# Go ↔ Swift panic boundary

Libbox / sing-box run inside the Network Extension. A Go panic that crosses the FFI boundary can take down the entire Packet Tunnel process.

## Rules

1. **Never feed unchecked user bytes to Libbox as “must succeed”.** Import / parse paths throw Swift errors or return diagnostics; they must not call into Go until a dictionary is built.
2. **`LibboxCheckConfig` before start.** Invalid JSON or unknown outbound types must fail the check with an error string — not abort the process.
3. **Capability fail-closed.** Missing tags (`with_mieru`, XHTTP, AWG, …) reject at the Swift builder; Core stubs return explicit “rebuild with -tags …” errors when a type is referenced without registration.
4. **Fuzz smoke.** `scripts/check_parser_execution.sh` feeds broken JSON / binary garbage to `sing-box check` and expects a non-zero exit (no crash dump).
5. **No invented outbound keys.** Do not emit `_vpndirect_*` or other unknown fields into runtime JSON.

## Regression expectation

- Invalid config → Swift/`sing-box check` error.
- Valid fixture families in `tests/fixtures/regression/` → check passes on a tagged Core build.
- NE must not trap solely because a subscription blob was malformed.
