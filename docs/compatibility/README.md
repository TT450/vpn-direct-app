# Compatibility & Providers

VPN Direct compatibility knowledge base — **source of truth** for panels, subscription HTTP, formats, and protocol edge cases.

> A panel is not “supported” because one sample link parses. Support requires researched generators, fixtures, unknown-field policy, and (for `tested`) live evidence.

| Doc | Purpose |
| --- | --- |
| [COMPATIBILITY_AUDIT.md](COMPATIBILITY_AUDIT.md) | Current DONE / PARTIAL / MISSING / BROKEN / UNPROVEN |
| [COMPATIBILITY_IMPLEMENTATION_PLAN.md](COMPATIBILITY_IMPLEMENTATION_PLAN.md) | Dependency-aware milestones |
| [ECOSYSTEMS.md](ECOSYSTEMS.md) | Ecosystem map (Xray, sing-box, WG/AWG, MASQUE, Mieru, …) |
| [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md) | Protocol × format × panel status |
| [SUBSCRIPTION_HTTP.md](SUBSCRIPTION_HTTP.md) | Client↔panel HTTP contract |
| [PANEL_VERSION_MATRIX.md](PANEL_VERSION_MATRIX.md) | Pinned upstream versions |
| [panels/](panels/) | Per-panel dossiers |
| [protocols/](protocols/) | Per-protocol dossiers |
| Machine-readable | [`core/panel-compatibility.json`](../../core/panel-compatibility.json) |

Golden donor behavior: [TheTochka harvest](../core/THETOCHKA_COMPATIBILITY_HARVEST.md) — behavior only, not architecture to copy.
