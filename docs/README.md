# VPN Direct Documentation

A compact map of the engineering documentation.

| Document | Use it for |
| --- | --- |
| [`core/CURRENT_ARCHITECTURE.md`](core/CURRENT_ARCHITECTURE.md) | Understanding the repository today |
| [`core/ARCHITECTURE.md`](core/ARCHITECTURE.md) | Target Core architecture |
| [`core/BUILDING.md`](core/BUILDING.md) | Reproducing Libbox and Apple builds |
| [`core/PROTOCOL_MATRIX.md`](core/PROTOCOL_MATRIX.md) | Authoritative protocol status |
| [`core/PRODUCTION_READINESS_AUDIT.md`](core/PRODUCTION_READINESS_AUDIT.md) | Honest readiness vs real code |
| [`core/VPN_DIRECT_PRODUCTION_PLAN.md`](core/VPN_DIRECT_PRODUCTION_PLAN.md) | Hardening milestones |
| [`core/THETOCHKA_COMPATIBILITY_HARVEST.md`](core/THETOCHKA_COMPATIBILITY_HARVEST.md) | Remnawave/Happ behaviors from TheTochka |
| [`core/VPN_DIRECT_CORE_PLAN.md`](core/VPN_DIRECT_CORE_PLAN.md) | Core roadmap |
| [`core/DONORS.md`](core/DONORS.md) | Upstream/donor source tracking |
| [`core/LICENSE_AUDIT.md`](core/LICENSE_AUDIT.md) | Dependency/license engineering notes |
| [`../ROADMAP.md`](../ROADMAP.md) | Public product roadmap |
| [`../WHATS_NEW.md`](../WHATS_NEW.md) | Latest release notes |
| [`../SUPPORT.md`](../SUPPORT.md) | How to get help |

## Support vocabulary

A protocol should move through explicit engineering states:

```text
parsed → compiled → validated → interop-tested → device-tested → production
```

A parser or builder alone is not proof of production support.
