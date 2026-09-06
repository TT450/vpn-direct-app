# VPN Direct Documentation

Engineering docs map (keep in sync with the GitHub README quick links: App Store · Architecture · Protocol Matrix · Build · Contribute).

| Document | Use it for |
| --- | --- |
| [`core/ARCHITECTURE.md`](core/ARCHITECTURE.md) | Target Core + subscription pipeline architecture |
| [`core/CURRENT_ARCHITECTURE.md`](core/CURRENT_ARCHITECTURE.md) | Understanding the repository today |
| [`core/BUILDING.md`](core/BUILDING.md) | Reproducing Libbox and Apple builds |
| [`core/PROTOCOL_MATRIX.md`](core/PROTOCOL_MATRIX.md) | Authoritative protocol status |
| [`../core/protocol-matrix.json`](../core/protocol-matrix.json) | Machine-readable matrix for CI / release gate |
| [`core/PRODUCTION_READINESS_AUDIT.md`](core/PRODUCTION_READINESS_AUDIT.md) | Honest readiness vs real code |
| [`core/VPN_DIRECT_PRODUCTION_PLAN.md`](core/VPN_DIRECT_PRODUCTION_PLAN.md) | Hardening milestones |
| [`core/THETOCHKA_COMPATIBILITY_HARVEST.md`](core/THETOCHKA_COMPATIBILITY_HARVEST.md) | Remnawave/Happ behaviors from TheTochka |
| [`core/MIERU_DEFERRED.md`](core/MIERU_DEFERRED.md) | Mieru Swift vs Core runtime status |
| [`device/IPHONE_QUALIFICATION.md`](device/IPHONE_QUALIFICATION.md) | Device evidence checklist |
| [`../interop/README.md`](../interop/README.md) | Interop lab scaffolds |
| [`core/DONORS.md`](core/DONORS.md) | Upstream/donor source tracking |
| [`core/LICENSE_AUDIT.md`](core/LICENSE_AUDIT.md) | Dependency/license engineering notes |
| [`../ROADMAP.md`](../ROADMAP.md) | Public product roadmap |
| [`../WHATS_NEW.md`](../WHATS_NEW.md) | Latest release notes (`v1.0.5`) |
| [`../SUPPORT.md`](../SUPPORT.md) | How to get help |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | PR / fixture / matrix rules |

## Support vocabulary

```text
parsed → compiled → validated → interop-tested → device-tested → production (`tested`)
```

A parser or builder alone is not proof of production support. `out_of_scope` rows are intentional non-goals for Core 1.x.
