#!/usr/bin/env bash
# Canonical Core tree preparation for VPN Direct.
# Idempotent, clean-clone safe, fail-closed.
#
# Usage:
#   scripts/prepare_core.sh           # apply overlays + verify
#   scripts/prepare_core.sh --verify  # verify only (fail if overlays missing)
#   scripts/prepare_core.sh --reset   # hard-reset submodule to VERSION pin, then apply
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
VERSION_FILE="${ROOT}/core/VERSION"
MODE="apply"

for arg in "$@"; do
  case "${arg}" in
    --verify) MODE="verify" ;;
    --reset) MODE="reset" ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

load_version() {
  if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "error: missing ${VERSION_FILE}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    if [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "${line?}"
    fi
  done < "${VERSION_FILE}"
}

verify_mieru_tree() {
  local missing=0
  for rel in \
    include/mieru.go \
    include/mieru_stub.go \
    option/mieru.go \
    protocol/mieru/outbound.go \
    protocol/mieru/inbound.go
  do
    if [[ ! -f "${CORE}/${rel}" ]]; then
      echo "MISSING ${CORE}/${rel}" >&2
      missing=1
    fi
  done
  if ! grep -q 'TypeMieru' "${CORE}/constant/proxy.go" 2>/dev/null; then
    echo "MISSING TypeMieru in constant/proxy.go" >&2
    missing=1
  fi
  if ! grep -q 'registerMieruOutbound' "${CORE}/include/registry.go" 2>/dev/null; then
    echo "MISSING registerMieruOutbound in include/registry.go" >&2
    missing=1
  fi
  if ! grep -q 'github.com/enfein/mieru/v3' "${CORE}/go.mod" 2>/dev/null; then
    echo "MISSING enfein/mieru/v3 in go.mod" >&2
    missing=1
  fi
  if [[ "${missing}" -ne 0 ]]; then
    echo "prepare_core verify FAILED" >&2
    exit 1
  fi
  echo "prepare_core verify OK (mieru overlays present)"
}

if [[ ! -d "${CORE}" ]]; then
  echo "error: ${CORE} missing — run: git submodule update --init --recursive" >&2
  echo "  or: ./scripts/bootstrap_core.sh" >&2
  exit 1
fi

load_version

case "${MODE}" in
  verify)
    verify_mieru_tree
    exit 0
    ;;
  reset)
    PIN="${SING_BOX_REV:-}"
    echo "prepare_core: resetting ${CORE} to pin ${PIN:-HEAD}"
    (
      cd "${CORE}"
      git fetch --tags origin 2>/dev/null || true
      if [[ -n "${PIN}" ]] && git rev-parse --verify "${PIN}^{commit}" >/dev/null 2>&1; then
        git checkout --force "${PIN}"
      elif [[ -n "${PIN}" ]] && git rev-parse --verify "tags/${PIN}" >/dev/null 2>&1; then
        git checkout --force "tags/${PIN}"
      else
        echo "warning: pin ${PIN} not resolvable; using current HEAD $(git rev-parse --short HEAD)" >&2
        git reset --hard HEAD
      fi
      git clean -fd
      git submodule update --init --recursive || true
    )
    ;;
esac

echo "prepare_core: applying sing-box overlays"
bash "${ROOT}/scripts/apply_singbox_overlays.sh"
verify_mieru_tree

# Optional: ensure go.sum has mieru after overlay (do not tidy away required deps)
if command -v go >/dev/null 2>&1; then
  (
    cd "${CORE}"
    if ! grep -q 'github.com/enfein/mieru/v3 v' go.mod; then
      go get github.com/enfein/mieru/v3@v3.36.1
    fi
  )
fi

echo "prepare_core OK"
