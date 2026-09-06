# VPN Direct Core 0.1 — Implementation Plan

See also the Cursor plan `vpn_direct_core`. This file is the in-repo source of truth.

## Goals

Replace stock Libbox with a reproducible **VPN Direct Core** Libbox built from a thin sing-box fork ([Leadaxe/sing-box-lx](https://github.com/Leadaxe/sing-box-lx)), keep Apple NetworkExtension architecture, add XHTTP / AmneziaWG / MASQUE / VLESS encryption, Capability Registry, and updated parsers.

## Layout

```text
core/sing-box/          # git submodule → sing-box-lx (recurse submodules for AWG)
core/VERSION            # pins
scripts/build_libbox.sh
Libbox.xcframework      # built output
Libbox.xcframework.stock/  # rollback backup
docs/core/
tests/fixtures/regression/
interop/
```

## Build profile `vpn_direct_ios`

```text
with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,
with_naive_outbound,with_clash_api,
with_xhttp,with_awg,with_lx_idle_suspend
```

Exclude for NE memory: `with_lxd`, Tailscale, OpenVPN/OpenConnect (deferred).

MASQUE / VLESS PQ ship with lx sources when enabled by tags/packages present in the fork.

Mieru: port from [enfein/mbox](https://github.com/enfein/mbox) behind `with_mieru` after baseline Libbox is green.

## Phases

1. Docs + license audit  
2. Submodule bootstrap  
3. `scripts/build_libbox.sh` + Makefile  
4. Wire xcframework into Apple project  
5. XHTTP builders (remove skip/fallback)  
6. AWG / MASQUE / VLESS encryption Swift models  
7. Capability Registry (Go export + Swift)  
8. Mieru or documented deferral  
9. Fixtures + PROTOCOL_MATRIX  

## Rollback

```bash
rm -rf Libbox.xcframework
cp -R Libbox.xcframework.stock Libbox.xcframework
```

## Acceptance

- Reproducible Libbox build  
- SFI builds against new Libbox  
- XHTTP no longer forced to httpupgrade / skipped in subscriptions  
- Capabilities readable from Swift  
- Docs complete  
