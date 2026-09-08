#!/usr/bin/env bash
# Apply VPN Direct sing-box overlays onto the checked-out pin.
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

copy_rel() {
  local rel="$1"
  local src="${OV}/${rel}"
  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${CORE}/${rel}")"
    cp -f "${src}" "${CORE}/${rel}"
    echo "  copied ${rel}"
  elif [[ -d "${src}" ]]; then
    mkdir -p "${CORE}/${rel}"
    # Directory tree copy (preserve relative structure)
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "${src}/" "${CORE}/${rel}/"
    else
      cp -R "${src}/." "${CORE}/${rel}/"
    fi
    echo "  synced ${rel}/"
  fi
}

# New / replacement sources (mirror relative paths under CORE)
for rel in \
  include/mieru.go \
  include/mieru_stub.go \
  include/shadowsocksr.go \
  include/shadowsocksr_stub.go \
  option/mieru.go \
  option/masque_connect_udp.go \
  protocol/mieru/inbound.go \
  protocol/mieru/outbound.go \
  protocol/masque_connect_udp/outbound.go \
  transport/masque/connect_udp.go \
  transport/masque/connect_udp_conn.go
do
  copy_rel "${rel}"
done

# Trees
for rel in protocol/shadowsocksr transport/clashssr; do
  if [[ -d "${OV}/${rel}" ]]; then
    copy_rel "${rel}"
  fi
done

apply_patch() {
  local patch="$1"
  local name="$2"
  if [[ ! -f "${patch}" ]]; then
    return 0
  fi
  if (cd "${CORE}" && git apply --check --whitespace=nowarn "${patch}" >/dev/null 2>&1); then
    (cd "${CORE}" && git apply --whitespace=nowarn "${patch}")
    echo "  applied ${name} via git apply"
  elif (cd "${CORE}" && patch -p1 --forward --dry-run < "${patch}" >/dev/null 2>&1); then
    (cd "${CORE}" && patch -p1 --forward --reject-file=- < "${patch}")
    echo "  applied ${name} via patch"
  else
    # Idempotent: markers already present
    echo "  ${name} already applied (or not applicable)"
  fi
}

PATCH_MIERU="${OV}/patches/mieru-stock.patch"
if [[ -f "${PATCH_MIERU}" ]]; then
  if grep -q 'TypeMieru' "${CORE}/constant/proxy.go" 2>/dev/null && \
     grep -q 'registerMieruOutbound' "${CORE}/include/registry.go" 2>/dev/null && \
     grep -q 'github.com/enfein/mieru/v3' "${CORE}/go.mod" 2>/dev/null; then
    echo "  mieru stock patch already applied (markers present)"
  else
    if (cd "${CORE}" && git apply --whitespace=nowarn "${PATCH_MIERU}"); then
      echo "  applied patches/mieru-stock.patch via git apply"
    elif (cd "${CORE}" && patch -p1 --forward --reject-file=- < "${PATCH_MIERU}"); then
      echo "  applied patches/mieru-stock.patch via patch"
    else
      echo "error: failed to apply ${PATCH_MIERU}" >&2
      exit 1
    fi
  fi
fi

PATCH_CONNECT="${OV}/patches/connect-udp-ssr-stock.patch"
if [[ -f "${PATCH_CONNECT}" ]]; then
  if grep -q 'TypeMASQUEConnectUDP' "${CORE}/constant/proxy.go" 2>/dev/null && \
     grep -q 'masqueconnectudp.RegisterOutbound' "${CORE}/include/quic.go" 2>/dev/null && \
     grep -q 'registerShadowsocksROutbound' "${CORE}/include/registry.go" 2>/dev/null && \
     grep -q 'with_shadowsocksr' "${CORE}/cmd/internal/build_libbox/main.go" 2>/dev/null && \
     grep -q 'Size cost is accepted for feature completeness' "${CORE}/cmd/internal/build_libbox/main.go" 2>/dev/null; then
    echo "  connect-udp/ssr stock patch already applied (markers present)"
  else
    if (cd "${CORE}" && git apply --whitespace=nowarn "${PATCH_CONNECT}"); then
      echo "  applied patches/connect-udp-ssr-stock.patch via git apply"
    elif (cd "${CORE}" && patch -p1 --forward --reject-file=- < "${PATCH_CONNECT}"); then
      echo "  applied patches/connect-udp-ssr-stock.patch via patch"
    else
      echo "error: failed to apply ${PATCH_CONNECT}" >&2
      exit 1
    fi
  fi
fi

# Sanity
for rel in \
  include/mieru.go \
  protocol/mieru/outbound.go \
  option/mieru.go \
  include/shadowsocksr.go \
  protocol/shadowsocksr/outbound.go \
  option/masque_connect_udp.go \
  protocol/masque_connect_udp/outbound.go \
  transport/masque/connect_udp.go
do
  if [[ ! -f "${CORE}/${rel}" ]]; then
    echo "error: overlay incomplete — missing ${CORE}/${rel}" >&2
    exit 1
  fi
done

if ! grep -q 'TypeMieru' "${CORE}/constant/proxy.go"; then
  echo "error: TypeMieru missing from constant/proxy.go after overlay" >&2
  exit 1
fi
if ! grep -q 'TypeMASQUEConnectUDP' "${CORE}/constant/proxy.go"; then
  echo "error: TypeMASQUEConnectUDP missing from constant/proxy.go after overlay" >&2
  exit 1
fi
if ! grep -q 'registerShadowsocksROutbound' "${CORE}/include/registry.go"; then
  echo "error: registerShadowsocksROutbound missing from include/registry.go after overlay" >&2
  exit 1
fi

echo "sing-box overlays applied OK"
