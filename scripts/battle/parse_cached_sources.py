#!/usr/bin/env python3
"""Parse cached public battle sources via `swift run BattleParse`."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REDACT_KEYS = ("password=", "uuid=", "private_key=", "token=")


def redact(text: str) -> str:
    out = text
    lower = out.lower()
    for key in REDACT_KEYS:
        # Case-insensitive simple redaction for log lines.
        idx = 0
        key_l = key.lower()
        while True:
            pos = lower.find(key_l, idx)
            if pos < 0:
                break
            end = pos + len(key)
            while end < len(out) and out[end] not in " \t\r\n&\"'":
                end += 1
            out = out[: pos + len(key)] + "***" + out[end:]
            lower = out.lower()
            idx = pos + len(key) + 3
    return out


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--cache-dir",
        type=Path,
        default=Path("tests/fixtures/battle/cache"),
        help="Fetcher cache directory containing manifest.json",
    )
    p.add_argument(
        "--package-path",
        type=Path,
        default=Path("tests/VPNDirectParserPackage"),
        help="Swift package path for BattleParse",
    )
    p.add_argument(
        "--out",
        type=Path,
        default=Path("artifacts/battle/parse-summary.json"),
        help="Aggregate JSON output path",
    )
    p.add_argument("--limit", type=int, default=200, help="BattleParse --limit N")
    p.add_argument(
        "--ids",
        default="",
        help="Comma-separated source ids (default: all OK in manifest)",
    )
    p.add_argument(
        "--require-cli",
        action="store_true",
        help="Fail if BattleParse cannot run (default: soft-skip as not_run)",
    )
    return p.parse_args()


def resolve_body(src_dir: Path, meta: dict[str, Any]) -> Path | None:
    body_file = meta.get("body_file")
    if isinstance(body_file, str) and body_file:
        candidate = src_dir / body_file
        if candidate.is_file():
            return candidate
    for name in ("body.txt", "body.bin"):
        candidate = src_dir / name
        if candidate.is_file():
            return candidate
    return None


def battle_parse_available(package_path: Path) -> tuple[bool, str]:
    if not package_path.is_dir():
        return False, f"missing package path: {package_path}"
    if shutil.which("swift") is None:
        return False, "swift not found on PATH"
    # Soft probe: help / usage. Do not force a full build here.
    # Presence of Sources/BattleParse or executable product is enough to attempt.
    battle_src = package_path / "Sources" / "BattleParse"
    pkg = package_path / "Package.swift"
    if not pkg.is_file():
        return False, "Package.swift missing"
    if not battle_src.exists():
        # Still try swift run — may be defined differently; but soft-skip by default.
        return False, "BattleParse sources not present yet (Sources/BattleParse)"
    return True, "ok"


def run_battle_parse(
    package_path: Path,
    body: Path,
    limit: int,
) -> dict[str, Any]:
    cmd = [
        "swift",
        "run",
        "--package-path",
        str(package_path),
        "BattleParse",
        "--input",
        str(body),
        "--limit",
        str(limit),
        "--json",
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
    except FileNotFoundError:
        return {
            "status": "not_run",
            "error": "swift not found",
            "command": cmd,
        }
    except subprocess.TimeoutExpired:
        return {
            "status": "PARSE_FAILED",
            "error": "BattleParse timed out",
            "command": cmd,
        }

    stdout = proc.stdout or ""
    stderr = proc.stderr or ""
    result: dict[str, Any] = {
        "status": "OK" if proc.returncode == 0 else "PARSE_FAILED",
        "exit_code": proc.returncode,
        "command": cmd,
        "stderr_redacted": redact(stderr[-4000:]),
    }
    payload = None
    text = stdout.strip()
    if text:
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            # Try last JSON object in output.
            start = text.rfind("{")
            end = text.rfind("}")
            if start >= 0 and end > start:
                try:
                    payload = json.loads(text[start : end + 1])
                except json.JSONDecodeError:
                    payload = None
    if payload is not None:
        result["battle_parse"] = payload
    else:
        result["stdout_redacted"] = redact(stdout[-4000:])
        if proc.returncode == 0:
            result["status"] = "PARSE_FAILED"
            result["error"] = "BattleParse returned non-JSON stdout"
        elif "error" not in result:
            result["error"] = "BattleParse failed"
    return result


def main() -> int:
    args = parse_args()
    cache_dir: Path = args.cache_dir
    manifest_path = cache_dir / "manifest.json"
    if not manifest_path.is_file():
        print(f"missing manifest: {manifest_path}", file=sys.stderr)
        return 1

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    id_filter = {x.strip() for x in args.ids.split(",") if x.strip()} or None

    available, reason = battle_parse_available(args.package_path)
    if not available and args.require_cli:
        print(f"BattleParse unavailable: {reason}", file=sys.stderr)
        return 1

    sources_out: list[dict[str, Any]] = []
    for entry in manifest.get("sources") or []:
        if not isinstance(entry, dict):
            continue
        sid = entry.get("id")
        if not isinstance(sid, str):
            continue
        if id_filter and sid not in id_filter:
            continue

        row: dict[str, Any] = {
            "id": sid,
            "fetch_status": entry.get("status"),
            "http_code": entry.get("http_code"),
            "bytes": entry.get("bytes"),
            "sha256": entry.get("sha256"),
            "content_type": entry.get("content_type"),
            "protocol": entry.get("protocol"),
            "variants": entry.get("variants"),
        }

        if entry.get("status") != "OK":
            row["parse_status"] = "skipped"
            row["error"] = f"fetch status {entry.get('status')}"
            sources_out.append(row)
            continue

        src_dir = cache_dir / sid
        meta_path = src_dir / "meta.json"
        meta = entry
        if meta_path.is_file():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                meta = entry

        body = resolve_body(src_dir, meta if isinstance(meta, dict) else {})
        if body is None:
            row["parse_status"] = "PARSE_FAILED"
            row["error"] = "missing body file"
            sources_out.append(row)
            continue

        if not available:
            row["parse_status"] = "not_run"
            row["error"] = reason
            sources_out.append(row)
            continue

        parsed = run_battle_parse(args.package_path, body, args.limit)
        row["parse_status"] = parsed.get("status")
        for k in ("battle_parse", "error", "exit_code", "stderr_redacted", "stdout_redacted"):
            if k in parsed:
                row[k] = parsed[k]
        sources_out.append(row)

    summary = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "cache_dir": str(cache_dir),
        "package_path": str(args.package_path),
        "limit": args.limit,
        "battle_parse_available": available,
        "battle_parse_note": reason if not available else None,
        "counts": {
            "total": len(sources_out),
            "OK": sum(1 for s in sources_out if s.get("parse_status") == "OK"),
            "PARSE_FAILED": sum(1 for s in sources_out if s.get("parse_status") == "PARSE_FAILED"),
            "not_run": sum(1 for s in sources_out if s.get("parse_status") == "not_run"),
            "skipped": sum(1 for s in sources_out if s.get("parse_status") == "skipped"),
        },
        "sources": sources_out,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"PARSE_SUMMARY {args.out} counts={summary['counts']}", flush=True)

    if args.require_cli and not available:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
