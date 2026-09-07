#!/usr/bin/env bash
# Orchestrate public battle catalog → fetch → parse → report.
# Volatile fetch emptiness must not fail the script unless the catalog is invalid.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

PUBLIC_ONLY=0
LOCAL_LAB=0
PROTOCOL="all"
LIMIT_PER_SOURCE=200
VALIDATE_ONLY=0
CONNECT=0
CONNECT_PUBLIC=0
OUTPUT_DIR="${ROOT}/artifacts/battle"
CACHE_DIR="${ROOT}/tests/fixtures/battle/cache"
CATALOG="${ROOT}/tests/battle/public-sources.json"

usage() {
  cat <<'EOF'
Usage: scripts/battle/run_battle_tests.sh [options]

  --public-only           Run public catalog pipeline only (default path)
  --local-lab             Also consider interop/protocols labs (connect stubs)
  --protocol X|all        Filter note for reports / future connect (default: all)
  --limit-per-source N    Pass --limit to BattleParse (default: 200)
  --validate-only         Catalog check + fetch + parse + report (no connect)
  --connect               Attempt local-lab connect (stub unless healthcheck exists)
  --connect-public        Opt-in public connect (stub; never required)
  --output DIR            Artifacts directory (default: artifacts/battle)
  -h, --help              Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --public-only) PUBLIC_ONLY=1; shift ;;
    --local-lab) LOCAL_LAB=1; shift ;;
    --protocol) PROTOCOL="${2:-all}"; shift 2 ;;
    --limit-per-source) LIMIT_PER_SOURCE="${2:-200}"; shift 2 ;;
    --validate-only) VALIDATE_ONLY=1; shift ;;
    --connect) CONNECT=1; shift ;;
    --connect-public) CONNECT_PUBLIC=1; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Default to public pipeline when nothing specified.
if [[ "${PUBLIC_ONLY}" -eq 0 && "${LOCAL_LAB}" -eq 0 ]]; then
  PUBLIC_ONLY=1
fi

mkdir -p "${OUTPUT_DIR}" "${CACHE_DIR}"

echo "==> Catalog check"
if ! "${ROOT}/scripts/battle/check_public_sources_catalog.sh" "${CATALOG}"; then
  echo "CATALOG_INVALID — failing run_battle_tests.sh" >&2
  exit 1
fi

FETCH_RC=0
echo "==> Fetch public sources → ${CACHE_DIR}"
if ! python3 "${ROOT}/scripts/battle/fetch_public_sources.py" \
  --catalog "${CATALOG}" \
  --out-dir "${CACHE_DIR}"; then
  FETCH_RC=$?
  echo "warning: fetch exited ${FETCH_RC} (volatile failures are non-fatal)" >&2
fi

echo "==> Parse cached sources (BattleParse)"
PARSE_RC=0
if ! python3 "${ROOT}/scripts/battle/parse_cached_sources.py" \
  --cache-dir "${CACHE_DIR}" \
  --package-path "${ROOT}/tests/VPNDirectParserPackage" \
  --out "${OUTPUT_DIR}/parse-summary.json" \
  --limit "${LIMIT_PER_SOURCE}"; then
  PARSE_RC=$?
  echo "warning: parse step exited ${PARSE_RC}" >&2
fi

echo "==> Generate public source report"
python3 "${ROOT}/scripts/battle/generate_public_source_report.py" \
  --manifest "${CACHE_DIR}/manifest.json" \
  --parse-summary "${OUTPUT_DIR}/parse-summary.json" \
  --out-dir "${OUTPUT_DIR}"

echo "protocol_filter=${PROTOCOL}" > "${OUTPUT_DIR}/run-meta.txt"
echo "public_only=${PUBLIC_ONLY}" >> "${OUTPUT_DIR}/run-meta.txt"
echo "local_lab=${LOCAL_LAB}" >> "${OUTPUT_DIR}/run-meta.txt"
echo "validate_only=${VALIDATE_ONLY}" >> "${OUTPUT_DIR}/run-meta.txt"
echo "connect=${CONNECT}" >> "${OUTPUT_DIR}/run-meta.txt"
echo "connect_public=${CONNECT_PUBLIC}" >> "${OUTPUT_DIR}/run-meta.txt"

connect_stub() {
  local label="$1"
  echo "CONNECT_STUB: ${label} — Network Extension live connect not implemented in this runner"
}

maybe_lab_healthcheck() {
  local family="$1"
  local hc="${ROOT}/interop/protocols/${family}/healthcheck"
  if [[ -x "${hc}" ]]; then
    echo "==> Lab healthcheck ${family}"
    "${hc}" || echo "warning: healthcheck ${family} failed (non-fatal for volatile policy)" >&2
    return 0
  fi
  if [[ -f "${hc}.sh" && -x "${hc}.sh" ]]; then
    echo "==> Lab healthcheck ${family}"
    "${hc}.sh" || echo "warning: healthcheck ${family} failed (non-fatal)" >&2
    return 0
  fi
  return 1
}

if [[ "${VALIDATE_ONLY}" -eq 1 ]]; then
  echo "==> --validate-only: skipping connect"
elif [[ "${CONNECT}" -eq 1 || "${CONNECT_PUBLIC}" -eq 1 ]]; then
  if [[ "${CONNECT}" -eq 1 || "${LOCAL_LAB}" -eq 1 ]]; then
    ANY_HC=0
    if [[ -d "${ROOT}/interop/protocols" ]]; then
      for d in "${ROOT}/interop/protocols"/*; do
        [[ -d "${d}" ]] || continue
        family="$(basename "${d}")"
        if [[ "${PROTOCOL}" != "all" && "${PROTOCOL}" != "${family}" ]]; then
          continue
        fi
        if maybe_lab_healthcheck "${family}"; then
          ANY_HC=1
        fi
      done
    fi
    if [[ "${ANY_HC}" -eq 0 ]]; then
      connect_stub "local-lab (no healthcheck scripts under interop/protocols/*/)"
    fi
  fi
  if [[ "${CONNECT_PUBLIC}" -eq 1 ]]; then
    connect_stub "public sources (NE connect not implemented; remote_server_dead would apply)"
  fi
fi

# Always exit 0 for volatile fetch failures unless catalog invalid (already exited 1).
echo "==> Done (fetch_rc=${FETCH_RC} parse_rc=${PARSE_RC}) — volatile fetch failures are non-fatal"
exit 0
