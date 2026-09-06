# License audit — VPN Direct Core

**Engineering interpretation only. Requires legal review before commercial / App Store distribution of a closed binary.**

| Component | License (confirmed upstream claim) | Copyleft | Notes |
|-----------|------------------------------------|----------|-------|
| SagerNet/sing-box | GPL-3.0 | Strong | Derivative works must comply with GPLv3 source obligations |
| Leadaxe/sing-box-lx | GPL-3.0 (inherits sing-box) | Strong | Same as upstream |
| enfein/mbox | Other / inherits sing-box (verify per release) | Likely strong | Confirm before merge |
| enfein/mieru | Check repo LICENSE | TBD | Reference / optional link |
| amneziawg-go | Check repo LICENSE | TBD | Reference tests |
| This Apple client | GPLv3 (see root LICENSE) | Strong | Already a modified sing-box-for-apple derivative |

## App Store / closed distribution

| Fact | Status |
|------|--------|
| Shipping a proprietary closed client linked to GPLv3 Libbox | **Requires legal review** — often treated as a distribution blocker without corresponding source offer |
| Prototype / TestFlight with matching source available | Aligns better with GPLv3 “corresponding source” practice |
| Engineering continues under Core 0.1 | Allowed as technical prototype; **not** a legal clearance |

## Confirmed vs interpretation

- **Confirmed:** sing-box and sing-box-lx are GPLv3.  
- **Interpretation:** VPN Direct Core Libbox is a derivative; source availability obligations apply when distributing binaries.  
- **Requires legal review:** Exact App Store compliance model, dual-licensing, or process-separation strategies.
