# HarmonyOS Core build profile

The repository's canonical Core pin remains in `core/VERSION`. HarmonyOS does not rewrite that file because the Apple build profile is still authoritative for the Apple client.

For HarmonyOS the adapter consumes the same source revision:

- Core: `0.1.0`
- Core name: `VPNDirectCore`
- sing-box remote: `Leadaxe/sing-box-lx`
- sing-box revision: `v1.14.0-lx.35`
- upstream baseline: `1.14.0`
- Go: `go1.26.6`

The Harmony build must translate the existing public Core overlays to the OpenHarmony/HarmonyOS ARM64 toolchain without changing protocol semantics.

## Required output

```text
harmony/entry/src/main/libs/arm64-v8a/libvpndirect_core.so
```

The final library must export:

```text
vpndirect_harmony_start
vpndirect_harmony_stop
```

The library is not committed to the public repository. It is a generated build artifact.
