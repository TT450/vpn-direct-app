# Compatibility & Providers

VPN Direct compatibility knowledge base — **source of truth** for panels, subscription HTTP, formats, and protocol edge cases.

> A panel is not “supported” because one sample link parses. Support requires researched generators, fixtures, unknown-field policy, and (for `tested`) live evidence.

| Doc | Purpose |
| --- | --- |
| [ECOSYSTEMS.md](ECOSYSTEMS.md) | Ecosystem map (Xray, sing-box, WG/AWG, MASQUE, Mieru, …) |
| [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md) | Protocol × format × panel status |
| [SUBSCRIPTION_HTTP.md](SUBSCRIPTION_HTTP.md) | Client↔panel HTTP contract |
| [PANEL_VERSION_MATRIX.md](PANEL_VERSION_MATRIX.md) | Pinned upstream versions |
| [panels/](panels/) | Per-panel dossiers |
| [protocols/](protocols/) | Per-protocol dossiers (incl. OpenVPN, Tailscale, MASQUE CONNECT-UDP) |
| Machine-readable | [`core/panel-compatibility.json`](../../core/panel-compatibility.json) |

Authoritative Core protocol status: [`docs/core/PROTOCOL_MATRIX.md`](../core/PROTOCOL_MATRIX.md). Remnawave/Happ topology behaviors are implemented in the production graph builder (not a separate harvest doc).
