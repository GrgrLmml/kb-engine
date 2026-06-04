#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Audit (and optionally fix) KB topic tags against the controlled vocabulary.

Reads the canonical vocabulary from kb-data/_topics.yaml, walks every .md file in
kb-data, and reports any topic tag that is an alias of a canonical term (drift) or
that collides with a known polysemous term. With --fix, rewrites the single
`topics: [...]` line in place (aliases -> canonical, deduped, order preserved) and
leaves the rest of each file byte-for-byte untouched.

Usage:
  audit-topics.py [--fix] [--kb-root PATH]

Exit code: 0 if no drift (or after a successful --fix), 1 if drift remains.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import yaml


def _default_kb_root() -> str:
    """KB_DATA_DIR env var, else <repo-root>/kb-data (repo root = parent of scripts/)."""
    return os.environ.get("KB_DATA_DIR") or str(Path(__file__).resolve().parent.parent / "kb-data")

TOPICS_RE = re.compile(r"^(?P<indent>\s*)topics:\s*\[(?P<body>.*)\]\s*$")


def load_vocab(kb_root: Path):
    vocab_path = kb_root / "_topics.yaml"
    data = yaml.safe_load(vocab_path.read_text()) or {}
    canonical = data.get("canonical", {}) or {}
    polysemous = data.get("polysemous", {}) or {}
    # alias(lowercased) -> canonical(exact)
    alias_map: dict[str, str] = {}
    canon_set = set()
    for canon, aliases in canonical.items():
        canon_set.add(canon)
        alias_map[canon.lower()] = canon  # canonical maps to itself
        for a in aliases or []:
            alias_map[str(a).lower()] = canon
    return alias_map, canon_set, polysemous


def split_tokens(body: str) -> list[str]:
    toks = []
    for raw in body.split(","):
        t = raw.strip().strip('"').strip("'")
        if t:
            toks.append(t)
    return toks


def normalize(tokens: list[str], alias_map: dict[str, str]):
    out, seen, changed = [], set(), False
    for t in tokens:
        canon = alias_map.get(t.lower(), t)
        if canon != t:
            changed = True
        if canon not in seen:
            seen.add(canon)
            out.append(canon)
        else:
            changed = True  # dedup
    return out, changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true", help="rewrite topics lines in place")
    ap.add_argument("--kb-root", default=_default_kb_root())
    args = ap.parse_args()

    kb_root = Path(args.kb_root)
    alias_map, canon_set, polysemous = load_vocab(kb_root)

    drift = 0
    poly_hits = 0
    for path in sorted(kb_root.rglob("*.md")):
        lines = path.read_text().splitlines(keepends=True)
        new_lines = list(lines)
        file_changed = False
        for i, line in enumerate(lines):
            m = TOPICS_RE.match(line.rstrip("\n"))
            if not m:
                continue
            tokens = split_tokens(m.group("body"))
            fixed, changed = normalize(tokens, alias_map)
            rel = path.relative_to(kb_root)
            for t in fixed:
                if t in polysemous:
                    print(f"  polysemy  kb:/{rel}: tag '{t}' is ambiguous — {polysemous[t]}")
                    poly_hits += 1
            if changed:
                drift += 1
                before = ", ".join(tokens)
                after = ", ".join(fixed)
                print(f"  drift     kb:/{rel}: [{before}] -> [{after}]")
                if args.fix:
                    new_lines[i] = f"{m.group('indent')}topics: [{after}]\n"
                    file_changed = True
        if file_changed:
            path.write_text("".join(new_lines))

    if args.fix:
        print(f"\nFixed {drift} topics line(s). Polysemy notes: {poly_hits} (review manually).")
        return 0
    if drift:
        print(f"\n{drift} topics line(s) have drift. Run with --fix to normalize. Polysemy notes: {poly_hits}.")
        return 1
    print(f"No topic drift. Polysemy notes: {poly_hits}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
