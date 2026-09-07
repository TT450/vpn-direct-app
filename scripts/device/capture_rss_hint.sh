#!/usr/bin/env bash
# Hint-only: how to capture process RSS on a paired iPhone for device evidence.
# Does not run Instruments or invent numbers. Always exits 0.
set -euo pipefail

cat <<'EOF'
# VPN Direct — RSS capture hints (device evidence)

Do not invent RSS numbers. Fill docs/device / interop/evidence only from a real run.

## Option A — xcrun devicectl (process list / diagnostics)

1. Pair the iPhone (Developer Mode + wireless debugging) on the same LAN as the Mac.
2. List devices:
     xcrun devicectl list devices
3. After installing/running the app, inspect processes (bundle / name may vary):
     xcrun devicectl device info processes --device <DEVICE_UDID>
   Look for the VPN Direct app and Packet Tunnel extension PIDs.
4. For deeper memory samples, prefer Instruments (Option B). `devicectl` alone
   does not replace a proper RSS timeline under traffic.

## Option B — Instruments (recommended for rss_* fields)

1. Open Xcode → Open Developer Tool → Instruments.
2. Choose Allocations or Activity Monitor; target the physical device + app.
3. Record:
   - rss_startup_mb      — shortly after launch, before connect
   - rss_connected_idle_mb — tunnel up, no active traffic
   - rss_under_traffic_mb  — during a sustained transfer
   - rss_peak_mb           — peak observed in the session
4. Export or note values into an evidence JSON matching
   docs/device/EVIDENCE_SCHEMA.md and interop/evidence/SCHEMA.json.

## Evidence

Copy the schema, fill pass/fail + Core SHA, leave unused fields null.
Store under interop/evidence/ (or interop/<family>/evidence/) — never commit secrets.
EOF

exit 0
