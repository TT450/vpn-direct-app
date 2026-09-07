#!/usr/bin/env bash
# Apply VPN Direct sing-box overlays (mieru protocol port) onto the checked-out pin.
# Idempotent: safe to run multiple times.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OV="${ROOT}/core/overlays/sing-box"

if [[ ! -d "${CORE}" ]]; then
  echo "error: ${CORE} missing — run scripts/bootstrap_core.sh first" >&2
  exit 1
fi

if [[ ! -d "${OV}" ]]; then
  echo "no sing-box overlays at ${OV}; skipping"
  exit 0
fi

echo "applying sing-box overlays from ${OV}"

# New / replacement sources (mirror relative paths under CORE)
for rel in \
  include/mieru.go \
  include/mieru_stub.go \
  option/mieru.go \
  protocol/mieru/inbound.go \
  protocol/mieru/outbound.go
do
  src="${OV}/${rel}"
  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${CORE}/${rel}")"
    cp -f "${src}" "${CORE}/${rel}"
    echo "  copied ${rel}"
  fi
done

PATCH="${OV}/patches/mieru-stock.patch"
if [[ -f "${PATCH}" ]]; then
  if grep -q 'TypeMieru' "${CORE}/constant/proxy.go" 2>/dev/null && \
     grep -q 'registerMieruOutbound' "${CORE}/include/registry.go" 2>/dev/null && \
     grep -q 'github.com/enfein/mieru/v3' "${CORE}/go.mod" 2>/dev/null; then
    echo "  mieru stock patch already applied (markers present)"
  else
    # Prefer git apply from CORE; fall back to patch(1)
    if (cd "${CORE}" && git apply --whitespace=nowarn "${PATCH}"); then
      echo "  applied patches/mieru-stock.patch via git apply"
    elif (cd "${CORE}" && patch -p1 --forward --reject-file=- < "${PATCH}"); then
      echo "  applied patches/mieru-stock.patch via patch"
    else
      echo "error: failed to apply ${PATCH}" >&2
      exit 1
    fi
  fi
fi

# Sanity
for rel in include/mieru.go protocol/mieru/outbound.go option/mieru.go; do
  if [[ ! -f "${CORE}/${rel}" ]]; then
    echo "error: overlay incomplete — missing ${CORE}/${rel}" >&2
    exit 1
  fi
done

if ! grep -q 'TypeMieru' "${CORE}/constant/proxy.go"; then
  echo "error: TypeMieru missing from constant/proxy.go after overlay" >&2
  exit 1
fi

echo "sing-box overlays applied OK"
