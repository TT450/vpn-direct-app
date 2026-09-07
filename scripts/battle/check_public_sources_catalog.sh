#!/usr/bin/env bash
# Offline validation of tests/battle/public-sources.json (no network).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="${1:-${ROOT}/tests/battle/public-sources.json}"

if [[ ! -f "${CATALOG}" ]]; then
  echo "MISSING catalog: ${CATALOG}" >&2
  exit 1
fi

python3 - "${CATALOG}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    print(f"INVALID_JSON: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print("INVALID: root must be an object", file=sys.stderr)
    sys.exit(1)

sources = data.get("sources")
if not isinstance(sources, list) or not sources:
    print("INVALID: sources must be a non-empty array", file=sys.stderr)
    sys.exit(1)

required = (
    "id",
    "protocol",
    "variants",
    "source_type",
    "url",
    "repository",
    "volatile",
    "intentional_public",
)

errors: list[str] = []
seen_ids: set[str] = set()

for idx, src in enumerate(sources):
    prefix = f"sources[{idx}]"
    if not isinstance(src, dict):
        errors.append(f"{prefix}: must be an object")
        continue

    for key in required:
        if key not in src:
            errors.append(f"{prefix}: missing required key '{key}'")

    sid = src.get("id")
    if not isinstance(sid, str) or not sid.strip():
        errors.append(f"{prefix}: id must be a non-empty string")
    elif sid in seen_ids:
        errors.append(f"{prefix}: duplicate id '{sid}'")
    else:
        seen_ids.add(sid)

    if "protocol" in src and (not isinstance(src["protocol"], str) or not src["protocol"].strip()):
        errors.append(f"{prefix}: protocol must be a non-empty string")

    variants = src.get("variants")
    if "variants" in src and (not isinstance(variants, list) or not variants or not all(isinstance(v, str) and v for v in variants)):
        errors.append(f"{prefix}: variants must be a non-empty string array")

    if "source_type" in src and (not isinstance(src["source_type"], str) or not src["source_type"].strip()):
        errors.append(f"{prefix}: source_type must be a non-empty string")

    url = src.get("url")
    if "url" in src:
        if not isinstance(url, str) or not url.startswith("https://"):
            errors.append(f"{prefix}: url must start with https://")

    repo = src.get("repository")
    if "repository" in src and (not isinstance(repo, str) or not repo.strip()):
        errors.append(f"{prefix}: repository must be a non-empty string")

    if "volatile" in src and src["volatile"] is not True:
        errors.append(f"{prefix}: volatile must be true")

    if "intentional_public" in src and src["intentional_public"] is not True:
        errors.append(f"{prefix}: intentional_public must be true")

if errors:
    for err in errors:
        print(err, file=sys.stderr)
    print(f"CATALOG_INVALID: {len(errors)} error(s) in {path}", file=sys.stderr)
    sys.exit(1)

print(f"CATALOG_OK {path} ({len(sources)} sources)")
PY
