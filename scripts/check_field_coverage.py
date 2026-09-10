#!/usr/bin/env python3
"""Fail if protocol-field-matrix marks SUPPORTED_AND_EMITTED without a builder path (REQ-TEST-field-coverage)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "core/protocol-field-matrix.json"


def main() -> int:
    data = json.loads(MATRIX.read_text())
    errors: list[str] = []
    allowed = {
        "SUPPORTED_AND_EMITTED",
        "SUPPORTED_PASSTHROUGH",
        "INTENTIONALLY_NOT_APPLICABLE",
        "EXPLICITLY_UNSUPPORTED",
    }
    for proto in data.get("protocols", []):
        for field in proto.get("fields", []):
            status = field.get("status")
            path = field.get("path")
            if status not in allowed:
                errors.append(f"{proto.get('protocol')}.{path}: illegal status {status!r}")
            if status == "SUPPORTED_AND_EMITTED":
                if not field.get("builder"):
                    errors.append(f"{proto.get('protocol')}.{path}: missing builder")
    if errors:
        print("FIELD COVERAGE FAIL:")
        for e in errors:
            print(" -", e)
        return 1
    print(f"FIELD COVERAGE OK ({sum(len(p.get('fields', [])) for p in data.get('protocols', []))} fields)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
