#!/usr/bin/env python3
"""Fail if any REMEDIATION_REQUIREMENTS.json id is missing from REMEDIATION_EXECUTION_PLAN.md."""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQ = ROOT / "docs" / "core" / "REMEDIATION_REQUIREMENTS.json"
PLAN = ROOT / "docs" / "core" / "REMEDIATION_EXECUTION_PLAN.md"


def main() -> int:
    if not REQ.is_file():
        print(f"MISSING {REQ}", file=sys.stderr)
        return 2
    if not PLAN.is_file():
        print(f"MISSING {PLAN}", file=sys.stderr)
        return 2

    data = json.loads(REQ.read_text(encoding="utf-8"))
    reqs = data["requirements"]
    plan = PLAN.read_text(encoding="utf-8")

    ids = [r["id"] for r in reqs]
    planned = [i for i in ids if i in plan]
    unplanned = [i for i in ids if i not in plan]
    by_status = Counter(r.get("status", "OPEN") for r in reqs)

    print(f"TOTAL={len(ids)}")
    print(f"PLANNED={len(planned)}")
    print(f"UNPLANNED={len(unplanned)}")
    print("BY_STATUS:")
    for k in sorted(by_status):
        print(f"  {k}={by_status[k]}")
    if unplanned:
        print("UNPLANNED_IDS:")
        for i in unplanned:
            print(f"  {i}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
