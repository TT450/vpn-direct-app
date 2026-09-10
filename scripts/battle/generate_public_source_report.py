#!/usr/bin/env python3
"""Merge fetch manifest + parse summary into public-source reports (no secrets)."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--manifest",
        type=Path,
        default=Path("tests/fixtures/battle/cache/manifest.json"),
    )
    p.add_argument(
        "--parse-summary",
        type=Path,
        default=Path("artifacts/battle/parse-summary.json"),
    )
    p.add_argument(
        "--out-dir",
        type=Path,
        default=Path("artifacts/battle"),
        help="Directory for public-source-report.json/.md",
    )
    return p.parse_args()


def counts_from_battle_parse(payload: dict[str, Any] | None) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {}
    # Accept either nested totals or flat keys from BattleParse.
    totals = payload.get("totals") if isinstance(payload.get("totals"), dict) else payload
    keys = (
        "total",
        "parsed",
        "unsupported",
        "malformed",
        "builder_failures",
        "core_failures",
        "entries",
    )
    out: dict[str, Any] = {}
    for k in keys:
        if k in totals:
            out[k] = totals[k]
    # Common aliases
    for src, dst in (
        ("total_entries", "total"),
        ("parsed_ok", "parsed"),
        ("builder_failed", "builder_failures"),
        ("core_failed", "core_failures"),
    ):
        if src in totals and dst not in out:
            out[dst] = totals[src]
    variants = payload.get("variants") or payload.get("sample_variants") or payload.get("discovered_variants")
    if variants is not None:
        out["sample_variants"] = variants
    return out


def pct(num: float | int | None, den: float | int | None) -> float | None:
    if num is None or den is None:
        return None
    try:
        d = float(den)
        if d <= 0:
            return None
        return round(100.0 * float(num) / d, 2)
    except (TypeError, ValueError):
        return None


def build_report(manifest: dict[str, Any], parse_summary: dict[str, Any] | None) -> dict[str, Any]:
    parse_by_id: dict[str, dict[str, Any]] = {}
    if parse_summary:
        for row in parse_summary.get("sources") or []:
            if isinstance(row, dict) and isinstance(row.get("id"), str):
                parse_by_id[row["id"]] = row

    sources_out: list[dict[str, Any]] = []
    for entry in manifest.get("sources") or []:
        if not isinstance(entry, dict):
            continue
        sid = entry.get("id")
        if not isinstance(sid, str):
            continue
        parsed = parse_by_id.get(sid, {})
        bp = parsed.get("battle_parse") if isinstance(parsed.get("battle_parse"), dict) else None
        stats = counts_from_battle_parse(bp)
        total = stats.get("total") or stats.get("entries")
        row = {
            "id": sid,
            "protocol": entry.get("protocol"),
            "variants": entry.get("variants"),
            "source_type": entry.get("source_type"),
            "repository": entry.get("repository"),
            "fetch_status": entry.get("status"),
            "http_code": entry.get("http_code"),
            "content_type": entry.get("content_type"),
            "bytes": entry.get("bytes"),
            "sha256": entry.get("sha256"),
            "parse_status": parsed.get("parse_status"),
            "entries": total,
            "parsed": stats.get("parsed"),
            "unsupported": stats.get("unsupported"),
            "malformed": stats.get("malformed"),
            "builder_failures": stats.get("builder_failures"),
            "core_failures": stats.get("core_failures"),
            "parsed_pct": pct(stats.get("parsed"), total),
            "unsupported_pct": pct(stats.get("unsupported"), total),
            "invalid_pct": pct(stats.get("malformed"), total),
            "sample_variants": stats.get("sample_variants"),
        }
        # Never include URL bodies or credentials — only hashes/counts/variants.
        sources_out.append(row)

    fetch_counts = manifest.get("counts") or {}
    parse_counts = (parse_summary or {}).get("counts") or {}

    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "policy": {
            "volatile": True,
            "credentials_in_report": False,
            "notes": "Hashes, counts, and variant labels only.",
        },
        "fetch_counts": fetch_counts,
        "parse_counts": parse_counts,
        "battle_parse_available": (parse_summary or {}).get("battle_parse_available"),
        "sources": sources_out,
    }


def render_md(report: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append("# Public source battle report")
    lines.append("")
    lines.append(f"Generated: `{report.get('generated_at')}`")
    lines.append("")
    lines.append("Credentials are never included (hashes / counts / variants only).")
    lines.append("")
    fc = report.get("fetch_counts") or {}
    pc = report.get("parse_counts") or {}
    lines.append("## Summary")
    lines.append("")
    lines.append(
        f"- Fetch: total={fc.get('total')} OK={fc.get('OK')} "
        f"EMPTY={fc.get('SOURCE_EMPTY')} FAILED={fc.get('SOURCE_FETCH_FAILED')}"
    )
    lines.append(
        f"- Parse: total={pc.get('total')} OK={pc.get('OK')} "
        f"FAILED={pc.get('PARSE_FAILED')} not_run={pc.get('not_run')} skipped={pc.get('skipped')}"
    )
    lines.append(f"- BattleParse available: `{report.get('battle_parse_available')}`")
    lines.append("")
    lines.append("## Per source")
    lines.append("")
    lines.append(
        "| id | fetch | http | bytes | parse | entries | parsed% | unsupported% | invalid% |"
    )
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for s in report.get("sources") or []:
        lines.append(
            "| {id} | {fetch} | {http} | {bytes} | {parse} | {entries} | {pp} | {up} | {ip} |".format(
                id=s.get("id"),
                fetch=s.get("fetch_status"),
                http=s.get("http_code"),
                bytes=s.get("bytes"),
                parse=s.get("parse_status"),
                entries=s.get("entries"),
                pp=s.get("parsed_pct"),
                up=s.get("unsupported_pct"),
                ip=s.get("invalid_pct"),
            )
        )
    lines.append("")
    lines.append("## Sample variants (when available)")
    lines.append("")
    for s in report.get("sources") or []:
        variants = s.get("sample_variants")
        if variants:
            lines.append(f"- **{s.get('id')}**: `{json.dumps(variants, ensure_ascii=False)}`")
    if not any((s.get("sample_variants") for s in (report.get("sources") or []))):
        lines.append("_No variant samples (BattleParse not_run or empty)._")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    if not args.manifest.is_file():
        print(f"missing manifest: {args.manifest}", file=sys.stderr)
        return 1

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    parse_summary = None
    if args.parse_summary.is_file():
        parse_summary = json.loads(args.parse_summary.read_text(encoding="utf-8"))
    else:
        print(f"warning: missing parse summary {args.parse_summary}; report will be fetch-only", flush=True)

    report = build_report(manifest, parse_summary)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.out_dir / "public-source-report.json"
    md_path = args.out_dir / "public-source-report.md"
    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    md_path.write_text(render_md(report), encoding="utf-8")
    print(f"REPORT {json_path}", flush=True)
    print(f"REPORT {md_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
