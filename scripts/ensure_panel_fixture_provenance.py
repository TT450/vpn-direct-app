#!/usr/bin/env python3
"""Ensure each panel fixture dir has at least one *.meta.json provenance file."""
from __future__ import annotations

import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PANELS = ROOT / "tests/fixtures/panels"

UPSTREAM = {
    "3x-ui": "https://github.com/MHSanaei/3x-ui",
    "x-ui": "https://github.com/vaxilu/x-ui",
    "tx-ui": "https://github.com/AghayeCoder/tx-ui",
    "marzban": "https://github.com/Gozargah/Marzban",
    "marzneshin": "https://github.com/marzneshin/marzneshin",
    "pasarguard": "https://github.com/PasarGuard/panel",
    "hiddify": "https://github.com/hiddify/Hiddify-Manager",
    "libertea": "https://github.com/VZiChoushaDui/Libertea",
    "s-ui": "https://github.com/alireza0/s-ui",
    "wg-easy": "https://github.com/wg-easy/wg-easy",
    "amnezia": "https://github.com/amnezia-vpn/amnezia-client",
    "remnawave": "https://github.com/remnawave/backend",
}


def main() -> None:
    for panel_dir in sorted(PANELS.iterdir()):
        if not panel_dir.is_dir():
            continue
        metas = list(panel_dir.glob("*.meta.json")) + list(panel_dir.glob("fixture.meta.json"))
        if metas:
            continue
        samples = [
            p
            for p in panel_dir.iterdir()
            if p.is_file() and p.suffix in {".json", ".yaml", ".yml", ".txt", ".conf"} and "meta" not in p.name
        ]
        sample = samples[0].name if samples else None
        meta = {
            "panel": panel_dir.name,
            "upstream": UPSTREAM.get(panel_dir.name, "unknown"),
            "commit": "unpinned-fixture-scaffold",
            "generator": "repo fixture / README-derived",
            "format": Path(sample).suffix.lstrip(".") if sample else "mixed",
            "sample": sample,
            "captured_from_generator": False,
            "sanitized": True,
            "date": date.today().isoformat(),
            "note": "Provenance scaffold for REQ-P010; replace with generator-captured output when available.",
        }
        (panel_dir / "fixture.meta.json").write_text(json.dumps(meta, indent=2) + "\n")
        print("wrote", panel_dir / "fixture.meta.json")


if __name__ == "__main__":
    main()
