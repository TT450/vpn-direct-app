# What's New — VPN Direct 1.0.6

Release date: 2026-09-07  
Git tag: `v1.0.6`

## App Store / short What's New

- Battle-key qualification ready: detectors, parsers, and Core cover declared protocols
- Mieru runtime registered behind `with_mieru` (TCP/UDP + traffic pattern)
- Clash nested Reality/WS/gRPC/plugin opts import
- Executable parser→`sing-box check` regression + interop lab templates (env battle keys)
- Honest matrix: Interop stays `planned` until you attach live evidence

## Engineering detail

- Ported `protocol/mieru` from enfein/mbox; tags in `vpn_direct_*.tags`
- Content detector schemes: shadowtls / naive / http-proxy family
- ClashYAMLAdapter nest flatten; VLESS/HY share links attributes-only (legacy outbound marked)
- `scripts/check_parser_execution.sh` + `docs/core/PANIC_BOUNDARY.md`
- Interop runnable templates: xray / hysteria / amnezia / mieru

### Still not `tested` / production-wide

Do not flip matrix rows to `tested` without `evidence.interop` + `evidence.device`. CONNECT-UDP / Tailscale / OpenVPN remain `out_of_scope`.

See also: `docs/core/PROTOCOL_MATRIX.md`, `ROADMAP.md`, `CHANGELOG.md`.
