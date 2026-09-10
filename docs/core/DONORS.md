# Donor audit — VPN Direct Core

| Feature | Primary source | Notes |
|---------|----------------|-------|
| Base engine | [SagerNet/sing-box](https://github.com/SagerNet/sing-box) | Upstream |
| XHTTP, AWG 2/3.x, MASQUE CONNECT-IP, VLESS encryption/PQ, idle-suspend | [Leadaxe/sing-box-lx](https://github.com/Leadaxe/sing-box-lx) | Thin fork; build tags `with_xhttp`, `with_awg`, … |
| AWG runtime | [Leadaxe/wireguard-go-awg2-lx](https://github.com/Leadaxe/wireguard-go-awg2-lx) | Submodule of sing-box-lx |
| AWG reference | [amnezia-vpn/amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go) | Interop / regression only |
| Mieru integration | [enfein/mbox](https://github.com/enfein/mbox) | Port package only, not whole fork |
| Mieru reference | [enfein/mieru](https://github.com/enfein/mieru) | Spec / server tests |
| Xray interop | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) | VLESS / XHTTP / Reality tests |
| Apple client patterns | This repo (from sing-box-for-apple) | Do not reinvent NE |

## Priority when features land upstream

1. SagerNet/sing-box  
2. sing-box-lx  
3. mbox (Mieru only)  
4. First-party VPN Direct code  

## Import record (fill on each cherry-pick)

| Feature | Origin repo | Commit / tag | Upstream base | Build tag | Local mods |
|---------|-------------|--------------|---------------|-----------|------------|
| Core baseline | Leadaxe/sing-box-lx | (pin in `core/VERSION`) | see `upstream.version` in submodule | `vpn_direct_ios` | version branding |
| Mieru | enfein/mbox | TBD | TBD | `with_mieru` | TBD |
