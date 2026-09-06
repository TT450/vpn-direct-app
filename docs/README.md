# VPN Direct Documentation

A compact map of the engineering documentation.

| Document | Use it for |
| --- | --- |
| [`core/CURRENT_ARCHITECTURE.md`](core/CURRENT_ARCHITECTURE.md) | Understanding the repository today |
| [`core/ARCHITECTURE.md`](core/ARCHITECTURE.md) | Target Core architecture |
| [`core/BUILDING.md`](core/BUILDING.md) | Reproducing Libbox and Apple builds |
| [`core/PROTOCOL_MATRIX.md`](core/PROTOCOL_MATRIX.md) | Authoritative protocol status |
| [`core/VPN_DIRECT_CORE_PLAN.md`](core/VPN_DIRECT_CORE_PLAN.md) | Core roadmap |
| [`core/DONORS.md`](core/DONORS.md) | Upstream/donor source tracking |
| [`core/LICENSE_AUDIT.md`](core/LICENSE_AUDIT.md) | Dependency/license engineering notes |

## Support vocabulary

A protocol should move through explicit engineering states:

```text
parsed → compiled → validated → interop-tested → device-tested → production
```

A parser or builder alone is not proof of production support.
