#!/usr/bin/env python3
"""Fetch intentional public battle sources into a local cache (gitignored)."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

USER_AGENT = "VPNDirect-Battle/1.0"
DEFAULT_MAX_BYTES = 8 * 1024 * 1024
SAFE_HEADER_ALLOWLIST = {
    "content-type",
    "content-length",
    "content-encoding",
    "etag",
    "last-modified",
    "cache-control",
    "expires",
    "date",
    "server",
    "x-content-type-options",
    "x-frame-options",
    "x-github-request-id",
    "x-ratelimit-limit",
    "x-ratelimit-remaining",
    "x-ratelimit-reset",
    "age",
    "vary",
}

REDACT_RE = re.compile(
    r"(?i)(password|uuid|private[_-]?key|token)\s*=\s*[^\s&\"']+",
)


def redact(text: str) -> str:
    return REDACT_RE.sub(lambda m: f"{m.group(1).lower()}=***", text)


def log(msg: str) -> None:
    print(redact(msg), flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--catalog",
        type=Path,
        default=Path("tests/battle/public-sources.json"),
        help="Path to public-sources.json",
    )
    p.add_argument(
        "--out-dir",
        type=Path,
        default=Path("tests/fixtures/battle/cache"),
        help="Cache output directory",
    )
    p.add_argument("--timeout", type=float, default=30.0, help="HTTP timeout seconds")
    p.add_argument(
        "--max-bytes",
        type=int,
        default=DEFAULT_MAX_BYTES,
        help="Max download size in bytes (default 8MiB)",
    )
    p.add_argument(
        "--ids",
        default="",
        help="Comma-separated source ids to fetch (default: all)",
    )
    p.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero if any source is not OK",
    )
    return p.parse_args()


def load_catalog(path: Path, id_filter: set[str] | None) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    sources = data.get("sources") or []
    if not isinstance(sources, list):
        raise SystemExit(f"invalid catalog: sources must be a list ({path})")
    out: list[dict[str, Any]] = []
    for src in sources:
        if not isinstance(src, dict):
            continue
        sid = src.get("id")
        if not isinstance(sid, str):
            continue
        if id_filter and sid not in id_filter:
            continue
        out.append(src)
    return out


def safe_headers(raw: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for k, v in raw.items():
        lk = k.lower()
        if lk in SAFE_HEADER_ALLOWLIST:
            out[lk] = redact(str(v))
    return out


def is_mostly_text(content_type: str | None, sample: bytes) -> bool:
    if content_type:
        ct = content_type.lower()
        if any(x in ct for x in ("text/", "json", "xml", "yaml", "javascript", "x-www-form-urlencoded")):
            return True
        if "octet-stream" in ct or "image/" in ct or "audio/" in ct or "video/" in ct:
            return False
    # Heuristic: no NULs in first 4KiB and mostly printable.
    head = sample[:4096]
    if b"\x00" in head:
        return False
    try:
        head.decode("utf-8")
        return True
    except UnicodeDecodeError:
        return False


def fetch_one(
    src: dict[str, Any],
    out_dir: Path,
    timeout: float,
    max_bytes: int,
) -> dict[str, Any]:
    sid = str(src["id"])
    url = str(src["url"])
    dest = out_dir / sid
    dest.mkdir(parents=True, exist_ok=True)

    meta: dict[str, Any] = {
        "id": sid,
        "url": url,
        "protocol": src.get("protocol"),
        "variants": src.get("variants"),
        "source_type": src.get("source_type"),
        "repository": src.get("repository"),
        "status": "SOURCE_FETCH_FAILED",
        "http_code": None,
        "bytes": 0,
        "sha256": None,
        "content_type": None,
        "error": None,
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "body_file": None,
    }

    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "*/*"},
        method="GET",
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            http_code = getattr(resp, "status", None) or resp.getcode()
            headers = {k: v for k, v in resp.headers.items()}
            content_type = resp.headers.get("Content-Type")
            chunks: list[bytes] = []
            total = 0
            truncated = False
            while True:
                chunk = resp.read(64 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > max_bytes:
                    # Keep only up to max_bytes.
                    overflow = total - max_bytes
                    if overflow < len(chunk):
                        chunks.append(chunk[: len(chunk) - overflow])
                    truncated = True
                    break
                chunks.append(chunk)
            body = b"".join(chunks)
    except urllib.error.HTTPError as exc:
        meta["http_code"] = int(exc.code)
        meta["error"] = redact(f"HTTPError: {exc.code} {exc.reason}")
        body = b""
        headers = {k: v for k, v in (exc.headers.items() if exc.headers else [])}
        content_type = headers.get("Content-Type") or headers.get("content-type")
        truncated = False
        try:
            raw = exc.read(max_bytes)
            body = raw or b""
        except Exception:
            body = b""
    except Exception as exc:  # noqa: BLE001 — surface any transport error
        meta["error"] = redact(f"{type(exc).__name__}: {exc}")
        (dest / "headers.json").write_text("{}", encoding="utf-8")
        (dest / "meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        log(f"FETCH {sid}: SOURCE_FETCH_FAILED ({meta['error']})")
        return meta

    meta["http_code"] = int(http_code) if http_code is not None else None
    meta["content_type"] = content_type
    meta["bytes"] = len(body)
    meta["sha256"] = hashlib.sha256(body).hexdigest() if body else None

    (dest / "headers.json").write_text(
        json.dumps(safe_headers(headers), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    if meta["http_code"] is not None and meta["http_code"] >= 400 and not body:
        meta["status"] = "SOURCE_FETCH_FAILED"
        if not meta["error"]:
            meta["error"] = f"HTTP {meta['http_code']}"
    elif not body.strip():
        meta["status"] = "SOURCE_EMPTY"
        meta["error"] = meta["error"] or "empty body"
    elif meta["http_code"] is not None and meta["http_code"] >= 400:
        meta["status"] = "SOURCE_FETCH_FAILED"
        if not meta["error"]:
            meta["error"] = f"HTTP {meta['http_code']}"
    else:
        meta["status"] = "OK"
        meta["error"] = None

    if truncated and meta["status"] == "OK":
        meta["error"] = f"truncated_to_{max_bytes}_bytes"
        # Still OK for parse smoke; note truncation.

    if body:
        textish = is_mostly_text(content_type, body)
        body_name = "body.txt" if textish else "body.bin"
        (dest / body_name).write_bytes(body)
        # Remove the alternate extension if present from a prior run.
        alt = dest / ("body.bin" if textish else "body.txt")
        if alt.exists():
            alt.unlink()
        meta["body_file"] = body_name
    else:
        meta["body_file"] = None

    (dest / "meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    log(
        f"FETCH {sid}: {meta['status']} http={meta['http_code']} bytes={meta['bytes']}"
        + (f" err={meta['error']}" if meta["error"] else "")
    )
    return meta


def main() -> int:
    args = parse_args()
    catalog = args.catalog
    if not catalog.is_file():
        print(f"missing catalog: {catalog}", file=sys.stderr)
        return 1

    id_filter = {x.strip() for x in args.ids.split(",") if x.strip()} or None
    sources = load_catalog(catalog, id_filter)
    if id_filter and not sources:
        print(f"no catalog entries match --ids {sorted(id_filter)}", file=sys.stderr)
        return 1

    out_dir: Path = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    started = time.time()
    results: list[dict[str, Any]] = []
    for src in sources:
        results.append(fetch_one(src, out_dir, args.timeout, args.max_bytes))

    ok = sum(1 for r in results if r["status"] == "OK")
    empty = sum(1 for r in results if r["status"] == "SOURCE_EMPTY")
    failed = sum(1 for r in results if r["status"] == "SOURCE_FETCH_FAILED")

    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "catalog": str(catalog),
        "out_dir": str(out_dir),
        "user_agent": USER_AGENT,
        "timeout": args.timeout,
        "max_bytes": args.max_bytes,
        "counts": {
            "total": len(results),
            "OK": ok,
            "SOURCE_EMPTY": empty,
            "SOURCE_FETCH_FAILED": failed,
        },
        "elapsed_sec": round(time.time() - started, 3),
        "sources": results,
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    log(
        f"MANIFEST {out_dir / 'manifest.json'} "
        f"OK={ok} EMPTY={empty} FAILED={failed} total={len(results)}"
    )

    if args.strict and (failed or empty):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
