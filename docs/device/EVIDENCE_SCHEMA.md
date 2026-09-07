# Device evidence JSON schema

Machine-readable companion: [`interop/evidence/SCHEMA.json`](../../interop/evidence/SCHEMA.json).

Use one JSON object per qualification run. **Do not invent RSS or pass/fail** — leave null / omit until a real device battle fills them.

## Required fields

| Field | Type | Description |
| --- | --- | --- |
| `schema` | number | Always `1` |
| `core_sha` | string | Git SHA (or Core stamp) of the build under test |
| `device` | string | Hardware model + OS (e.g. `iPhone15,2 iOS 18.x`) |
| `protocol` | string | Protocol under test (`vless`, `hysteria2`, …) |
| `panel` | string \| null | Panel id if subscription-sourced (`remnawave`, `marzban`, …); else null |
| `rss_startup_mb` | number \| null | RSS shortly after launch (MB) |
| `rss_connected_idle_mb` | number \| null | RSS with tunnel up, idle (MB) |
| `rss_under_traffic_mb` | number \| null | RSS during sustained traffic (MB) |
| `rss_peak_mb` | number \| null | Peak RSS in the session (MB) |
| `pass` | boolean \| null | Overall row pass/fail; null until judged |
| `fail` | boolean \| null | Explicit fail flag if preferred over `pass:false`; null until judged |
| `notes` | string \| null | Free-form notes / Instruments export path |
| `date` | string \| null | ISO-8601 UTC date of the run |

## Example (empty evidence — ready, not filled)

```json
{
  "schema": 1,
  "core_sha": "",
  "device": "",
  "protocol": "",
  "panel": null,
  "rss_startup_mb": null,
  "rss_connected_idle_mb": null,
  "rss_under_traffic_mb": null,
  "rss_peak_mb": null,
  "pass": null,
  "fail": null,
  "notes": null,
  "date": null
}
```

See also: [IPHONE_QUALIFICATION.md](IPHONE_QUALIFICATION.md), `scripts/device/capture_rss_hint.sh`.
