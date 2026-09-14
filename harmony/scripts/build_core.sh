#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="${ROOT_DIR}/core/VERSION"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "ERROR: core/VERSION not found" >&2
  exit 1
fi

# Keep the public build pinned to the repository's Core baseline.
CORE_VERSION="$(grep '^CORE_VERSION=' "${VERSION_FILE}" | cut -d= -f2-)"
CORE_NAME="$(grep '^CORE_NAME=' "${VERSION_FILE}" | cut -d= -f2-)"
SING_BOX_REV="$(grep '^SING_BOX_REV=' "${VERSION_FILE}" | cut -d= -f2-)"

printf 'VPN Direct HarmonyOS Core build gate\n'
printf '  Core: %s (%s)\n' "${CORE_NAME}" "${CORE_VERSION}"
printf '  sing-box-lx: %s\n' "${SING_BOX_REV}"

if [[ "${CORE_VERSION}" != "0.1.0" ]]; then
  echo "ERROR: unexpected Core version; refuse to substitute another Core." >&2
  exit 1
fi

if [[ "${SING_BOX_REV}" != "v1.14.0-lx.35" ]]; then
  echo "ERROR: unexpected sing-box revision; refuse to substitute another build." >&2
  exit 1
fi

cat <<'EOF'

The HarmonyOS Core build is intentionally gated here until the OpenHarmony/
HarmonyOS ARM64 toolchain and the repository's Core wrapper are available.

Required implementation:
  1. Build VPN Direct Core 0.1.0 for HarmonyOS ARM64.
  2. Apply the existing public Core overlays.
  3. Export vpndirect_harmony_start / vpndirect_harmony_stop.
  4. Produce libvpndirect_core.so.
  5. Link it into harmony/entry/src/main/cpp.

Do not use an Android GOOS, an Android .so, or an unrelated stock sing-box
binary as a substitute.
EOF

exit 2
