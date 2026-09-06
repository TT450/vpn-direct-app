# Core remotes

## `core/sing-box`

Thin fork tracked as a **local clone** (or git submodule when publishing):

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `https://github.com/Leadaxe/sing-box-lx.git` | Current Core 0.1 donor (`lx` branch) |
| `upstream` | `https://github.com/SagerNet/sing-box.git` | Official sing-box (rebase source) |

When VPN Direct publishes its own fork, point `origin` at that fork and keep `upstream` as SagerNet plus an optional `lx` remote for Leadaxe merges.

## Bootstrap

```bash
./scripts/bootstrap_core.sh
# or
git submodule update --init --recursive
```

Pins land in [`core/VERSION`](../../core/VERSION) (revision, Go pin, build tags).

## Nested submodules

`sing-box-lx` pulls AWG `wireguard-go` and client trees. For Libbox Apple builds you need at least the AWG-related submodules when `with_awg` is in `vpn_direct_ios` tags. Prefer:

```bash
cd core/sing-box && git submodule update --init --recursive
```

If Apple/Android/desktop client submodules are slow to fetch, a shallow bootstrap may still leave enough for `cmd/internal/build_libbox` once Go packages and `with_awg` deps resolve.
