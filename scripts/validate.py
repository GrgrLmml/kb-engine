#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml>=6"]
# ///
"""
Validate Gregor's KB schema invariants. Walks kb-data/, parses every .md
file's YAML frontmatter, and reports any schema violations.

Exits 0 if all invariants hold, 1 if any errors.

Usage:
    validate.py                  # validate the whole tree
    validate.py --quiet          # only print errors, no summary
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml


# YAML by default auto-parses ISO 8601 timestamps to datetime objects, which
# would defeat our "is this a properly-formatted timestamp string?" check.
# Strip the timestamp resolver so they stay as strings.
class StrLoader(yaml.SafeLoader):
    pass


StrLoader.yaml_implicit_resolvers = {
    k: [(tag, regexp) for (tag, regexp) in resolvers
        if tag != "tag:yaml.org,2002:timestamp"]
    for k, resolvers in StrLoader.yaml_implicit_resolvers.items()
}


# KB_DATA_DIR env var, else <repo-root>/kb-data (repo root = parent of scripts/).
KB_ROOT = Path(os.environ.get("KB_DATA_DIR") or (Path(__file__).resolve().parent.parent / "kb-data"))

ENTRY_REQUIRED = {"id", "title", "created", "updated", "status", "summary"}
ENTRY_OPTIONAL_PRESENT = {
    "participants", "topics", "related", "sources",
    "supersedes", "superseded_by", "contradicts",
    "decisions", "open_questions", "recipe_candidate",
}
ENTRY_ALL = ENTRY_REQUIRED | ENTRY_OPTIONAL_PRESENT

ROUTE_REQUIRED = {"type", "folder", "title", "purpose", "last_indexed"}
ROUTE_OPTIONAL_PRESENT = {"topics", "subroutes", "entries", "related"}
ROUTE_ALL = ROUTE_REQUIRED | ROUTE_OPTIONAL_PRESENT

# Recipes are evergreen procedural leaves (type: recipe), distinct from episodic
# entries. They share the leaf machinery (id==stem, listed in parent route) but
# carry procedural fields and have no date-prefixed id.
RECIPE_REQUIRED = {"type", "id", "title", "created", "updated", "status",
                   "when_to_use", "tools", "steps", "summary"}
RECIPE_OPTIONAL_PRESENT = {
    "inputs", "topics", "skill", "derived_from",
    "related", "sources", "supersedes", "superseded_by", "last_verified",
}
RECIPE_ALL = RECIPE_REQUIRED | RECIPE_OPTIONAL_PRESENT

# Models are evergreen declarative leaves (type: model) — the theory layer.
# Same leaf machinery as recipes (id==stem, no date prefix, listed in parent
# route) but carry a falsifiable statement + prediction/evidence fields.
MODEL_REQUIRED = {"type", "id", "title", "created", "updated", "status",
                  "statement", "summary"}
MODEL_OPTIONAL_PRESENT = {
    "predictions", "derived_from", "evidence_for", "refuted_by",
    "topics", "related", "sources", "supersedes", "superseded_by",
}
MODEL_ALL = MODEL_REQUIRED | MODEL_OPTIONAL_PRESENT

VALID_STATUS = {"active", "superseded", "archived"}
RECIPE_VALID_STATUS = {"active", "draft", "superseded"}
MODEL_VALID_STATUS = {"hypothesis", "validated", "refuted", "superseded"}
ISO_UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


@dataclass
class Validator:
    errors: list[tuple[Path, str]] = field(default_factory=list)
    ids_seen: dict[str, Path] = field(default_factory=dict)
    routes: dict[Path, dict] = field(default_factory=dict)   # _route.md path -> frontmatter
    entries: dict[Path, dict] = field(default_factory=dict)  # episodic leaf path -> frontmatter
    recipes: dict[Path, dict] = field(default_factory=dict)  # recipe leaf path -> frontmatter
    models: dict[Path, dict] = field(default_factory=dict)   # model leaf path -> frontmatter

    def err(self, path: Path, msg: str) -> None:
        self.errors.append((path, msg))

    # ------------------------------------------------------------------ helpers

    def parse_frontmatter(self, path: Path) -> dict | None:
        try:
            text = path.read_text()
        except Exception as e:
            self.err(path, f"could not read file: {e}")
            return None
        if not text.startswith("---\n"):
            self.err(path, "missing frontmatter (no leading '---')")
            return None
        try:
            end = text.index("\n---\n", 4)
        except ValueError:
            self.err(path, "frontmatter not closed (no '---' on its own line)")
            return None
        try:
            fm = yaml.load(text[4:end], Loader=StrLoader)
        except yaml.YAMLError as e:
            self.err(path, f"YAML parse error: {e}")
            return None
        if not isinstance(fm, dict):
            self.err(path, "frontmatter is not a mapping")
            return None
        return fm

    def kb_to_disk(self, kb_path: str) -> Path | None:
        if not isinstance(kb_path, str) or not kb_path.startswith("kb:/"):
            return None
        rel = kb_path[len("kb:/"):]
        return KB_ROOT if rel == "" else KB_ROOT / rel

    def disk_to_kb(self, disk_path: Path) -> str:
        if disk_path == KB_ROOT:
            return "kb:/"
        return "kb:/" + str(disk_path.relative_to(KB_ROOT))

    def check_kb_path(self, file: Path, field_name: str, value: object) -> None:
        if not isinstance(value, str):
            self.err(file, f"{field_name}: expected string, got {type(value).__name__}")
            return
        if not value.startswith("kb:/"):
            self.err(file, f"{field_name}: not a kb:/ URI: {value!r}")
            return
        disk = self.kb_to_disk(value)
        if disk is None or not disk.exists():
            self.err(file, f"{field_name}: kb:/ path does not exist on disk: {value}")

    def check_iso_utc(self, file: Path, field_name: str, value: object) -> None:
        if not isinstance(value, str):
            self.err(file, f"{field_name}: not a string")
            return
        if not ISO_UTC_RE.match(value):
            self.err(file, f"{field_name}: not ISO 8601 UTC (YYYY-MM-DDTHH:MM:SSZ): {value!r}")

    def check_unknown_keys(self, file: Path, fm: dict, allowed: set[str], kind: str) -> None:
        unknown = set(fm.keys()) - allowed
        if unknown:
            self.err(file, f"{kind} has unknown frontmatter keys: {sorted(unknown)}")

    # ------------------------------------------------------------- entry checks

    def validate_entry(self, file: Path, fm: dict) -> None:
        self.entries[file] = fm

        missing = ENTRY_REQUIRED - set(fm.keys())
        if missing:
            self.err(file, f"missing required leaf fields: {sorted(missing)}")
        self.check_unknown_keys(file, fm, ENTRY_ALL, "leaf entry")

        # id matches filename stem; ids unique tree-wide
        expected_id = file.stem
        actual_id = fm.get("id")
        if isinstance(actual_id, str):
            if actual_id != expected_id:
                self.err(file, f"id={actual_id!r} doesn't match filename stem {expected_id!r}")
            if actual_id in self.ids_seen and self.ids_seen[actual_id] != file:
                self.err(file, f"duplicate id {actual_id!r} (also at {self.ids_seen[actual_id]})")
            else:
                self.ids_seen[actual_id] = file

        # status
        if "status" in fm and fm["status"] not in VALID_STATUS:
            self.err(file, f"status must be one of {sorted(VALID_STATUS)}, got {fm['status']!r}")

        # timestamps
        for f_name in ("created", "updated"):
            if f_name in fm:
                self.check_iso_utc(file, f_name, fm[f_name])

        # related: kb:/ paths to existing files
        for v in fm.get("related") or []:
            self.check_kb_path(file, "related[]", v)

        # sources: http(s) URLs
        for v in fm.get("sources") or []:
            if not isinstance(v, str) or not (v.startswith("http://") or v.startswith("https://")):
                self.err(file, f"sources[] not an http(s) URL: {v!r}")

        # supersedes/contradicts/superseded_by: bare ids, NOT kb:/ paths
        for f_name in ("supersedes", "contradicts"):
            for v in fm.get(f_name) or []:
                if not isinstance(v, str) or v.startswith("kb:/") or v.startswith("http"):
                    self.err(file, f"{f_name}[] should be a bare id, got: {v!r}")
        sb = fm.get("superseded_by")
        if sb is not None and (not isinstance(sb, str) or sb.startswith("kb:/") or sb.startswith("http")):
            self.err(file, f"superseded_by should be null or a bare id, got: {sb!r}")

        # summary present and non-trivial
        summary = fm.get("summary")
        if isinstance(summary, str) and len(summary.strip()) < 20:
            self.err(file, f"summary too short ({len(summary.strip())} chars) — make it WARM-tier useful")

        # recipe_candidate: bool if present (auto-flag for the mining pass)
        rc = fm.get("recipe_candidate")
        if rc is not None and not isinstance(rc, bool):
            self.err(file, f"recipe_candidate must be true/false, got: {rc!r}")

    # ------------------------------------------------------------ recipe checks

    def validate_recipe(self, file: Path, fm: dict) -> None:
        self.recipes[file] = fm

        missing = RECIPE_REQUIRED - set(fm.keys())
        if missing:
            self.err(file, f"missing required recipe fields: {sorted(missing)}")
        self.check_unknown_keys(file, fm, RECIPE_ALL, "recipe")

        if fm.get("type") != "recipe":
            self.err(file, f"type must be 'recipe', got: {fm.get('type')!r}")

        # id matches filename stem (no date prefix); ids unique tree-wide
        expected_id = file.stem
        actual_id = fm.get("id")
        if isinstance(actual_id, str):
            if actual_id != expected_id:
                self.err(file, f"id={actual_id!r} doesn't match filename stem {expected_id!r}")
            if actual_id in self.ids_seen and self.ids_seen[actual_id] != file:
                self.err(file, f"duplicate id {actual_id!r} (also at {self.ids_seen[actual_id]})")
            else:
                self.ids_seen[actual_id] = file

        # status
        if "status" in fm and fm["status"] not in RECIPE_VALID_STATUS:
            self.err(file, f"recipe status must be one of {sorted(RECIPE_VALID_STATUS)}, got {fm['status']!r}")

        # timestamps
        for f_name in ("created", "updated"):
            if f_name in fm:
                self.check_iso_utc(file, f_name, fm[f_name])
        lv = fm.get("last_verified")
        if lv is not None:
            self.check_iso_utc(file, "last_verified", lv)

        # when_to_use: a descriptive trigger string
        wtu = fm.get("when_to_use")
        if not isinstance(wtu, str) or len(wtu.strip()) < 10:
            self.err(file, "when_to_use must be a descriptive string (>=10 chars)")

        # tools: normalized bare tokens (not kb:/ or http)
        tools = fm.get("tools")
        if not isinstance(tools, list):
            self.err(file, "tools must be a list")
        else:
            for t in tools:
                if not isinstance(t, str) or t.startswith("kb:/") or t.startswith("http"):
                    self.err(file, f"tools[] should be a bare token, got: {t!r}")

        # steps: non-empty ordered list
        steps = fm.get("steps")
        if not isinstance(steps, list) or len(steps) == 0:
            self.err(file, "steps must be a non-empty list")

        # inputs: list if present
        inputs = fm.get("inputs")
        if inputs is not None and not isinstance(inputs, list):
            self.err(file, "inputs must be a list")

        # skill: null or a skill-name string
        skill = fm.get("skill")
        if skill is not None and not isinstance(skill, str):
            self.err(file, f"skill must be null or a skill name string, got: {skill!r}")

        # derived_from / supersedes: bare ids, NOT kb:/ paths
        for f_name in ("derived_from", "supersedes"):
            for v in fm.get(f_name) or []:
                if not isinstance(v, str) or v.startswith("kb:/") or v.startswith("http"):
                    self.err(file, f"{f_name}[] should be a bare id, got: {v!r}")
        sb = fm.get("superseded_by")
        if sb is not None and (not isinstance(sb, str) or sb.startswith("kb:/") or sb.startswith("http")):
            self.err(file, f"superseded_by should be null or a bare id, got: {sb!r}")

        # related: kb:/ paths to existing files
        for v in fm.get("related") or []:
            self.check_kb_path(file, "related[]", v)

        # sources: http(s) URLs
        for v in fm.get("sources") or []:
            if not isinstance(v, str) or not (v.startswith("http://") or v.startswith("https://")):
                self.err(file, f"sources[] not an http(s) URL: {v!r}")

        # summary present and non-trivial
        summary = fm.get("summary")
        if isinstance(summary, str) and len(summary.strip()) < 20:
            self.err(file, f"summary too short ({len(summary.strip())} chars) — make it WARM-tier useful")

    # ------------------------------------------------------------- model checks

    def validate_model(self, file: Path, fm: dict) -> None:
        self.models[file] = fm

        missing = MODEL_REQUIRED - set(fm.keys())
        if missing:
            self.err(file, f"missing required model fields: {sorted(missing)}")
        self.check_unknown_keys(file, fm, MODEL_ALL, "model")

        if fm.get("type") != "model":
            self.err(file, f"type must be 'model', got: {fm.get('type')!r}")

        # id matches filename stem (no date prefix); ids unique tree-wide
        expected_id = file.stem
        actual_id = fm.get("id")
        if isinstance(actual_id, str):
            if actual_id != expected_id:
                self.err(file, f"id={actual_id!r} doesn't match filename stem {expected_id!r}")
            if actual_id in self.ids_seen and self.ids_seen[actual_id] != file:
                self.err(file, f"duplicate id {actual_id!r} (also at {self.ids_seen[actual_id]})")
            else:
                self.ids_seen[actual_id] = file

        # status + status/evidence consistency
        status = fm.get("status")
        if "status" in fm and status not in MODEL_VALID_STATUS:
            self.err(file, f"model status must be one of {sorted(MODEL_VALID_STATUS)}, got {status!r}")
        if status == "validated" and not fm.get("evidence_for"):
            self.err(file, "status 'validated' requires non-empty evidence_for")
        if status == "refuted" and not fm.get("refuted_by"):
            self.err(file, "status 'refuted' requires non-empty refuted_by")

        # timestamps
        for f_name in ("created", "updated"):
            if f_name in fm:
                self.check_iso_utc(file, f_name, fm[f_name])

        # statement: the falsifiable premise — load-bearing
        stmt = fm.get("statement")
        if not isinstance(stmt, str) or len(stmt.strip()) < 20:
            self.err(file, "statement must be a substantive claim (>=20 chars)")

        # predictions: list of strings if present
        preds = fm.get("predictions")
        if preds is not None and not isinstance(preds, list):
            self.err(file, "predictions must be a list")

        # grounding must not double as confirmation (circularity guard)
        derived = set(fm.get("derived_from") or [])
        evidence = set(fm.get("evidence_for") or [])
        circular = derived & evidence
        if circular:
            self.err(file, f"evidence_for overlaps derived_from (circular): {sorted(circular)}")

        # derived_from / evidence_for / refuted_by / supersedes: bare ids
        for f_name in ("derived_from", "evidence_for", "refuted_by", "supersedes"):
            for v in fm.get(f_name) or []:
                if not isinstance(v, str) or v.startswith("kb:/") or v.startswith("http"):
                    self.err(file, f"{f_name}[] should be a bare id, got: {v!r}")
        sb = fm.get("superseded_by")
        if sb is not None and (not isinstance(sb, str) or sb.startswith("kb:/") or sb.startswith("http")):
            self.err(file, f"superseded_by should be null or a bare id, got: {sb!r}")

        # related: kb:/ paths to existing files
        for v in fm.get("related") or []:
            self.check_kb_path(file, "related[]", v)

        # sources: http(s) URLs
        for v in fm.get("sources") or []:
            if not isinstance(v, str) or not (v.startswith("http://") or v.startswith("https://")):
                self.err(file, f"sources[] not an http(s) URL: {v!r}")

        # summary present and non-trivial
        summary = fm.get("summary")
        if isinstance(summary, str) and len(summary.strip()) < 20:
            self.err(file, f"summary too short ({len(summary.strip())} chars) — make it WARM-tier useful")

    # ------------------------------------------------------------- route checks

    def validate_route(self, file: Path, fm: dict) -> None:
        self.routes[file] = fm

        missing = ROUTE_REQUIRED - set(fm.keys())
        if missing:
            self.err(file, f"missing required route fields: {sorted(missing)}")
        self.check_unknown_keys(file, fm, ROUTE_ALL, "route")

        if fm.get("type") != "route":
            self.err(file, f"type must be 'route', got: {fm.get('type')!r}")

        # folder field matches actual location
        actual_folder = self.disk_to_kb(file.parent)
        if "folder" in fm and fm["folder"] != actual_folder:
            self.err(file, f"folder={fm['folder']!r} doesn't match actual location {actual_folder!r}")

        # last_indexed timestamp
        if "last_indexed" in fm:
            self.check_iso_utc(file, "last_indexed", fm["last_indexed"])

        # subroutes: each must be a kb:/ path to an existing _route.md
        for sub in fm.get("subroutes") or []:
            if not isinstance(sub, dict):
                self.err(file, f"subroutes[] entry not a mapping: {sub!r}")
                continue
            path = sub.get("path")
            self.check_kb_path(file, "subroutes[].path", path)
            disk = self.kb_to_disk(path) if isinstance(path, str) else None
            if disk and disk.exists() and disk.name != "_route.md":
                self.err(file, f"subroutes[].path doesn't point at a _route.md: {path}")
            if "summary" not in sub:
                self.err(file, f"subroutes[] missing 'summary' for {path!r}")

        # entries: each must reference an existing leaf
        for ent in fm.get("entries") or []:
            if not isinstance(ent, dict):
                self.err(file, f"entries[] entry not a mapping: {ent!r}")
                continue
            self.check_kb_path(file, "entries[].file", ent.get("file"))
            for k in ("id", "summary"):
                if k not in ent:
                    self.err(file, f"entries[] missing {k!r}: {ent!r}")

        # related: kb:/ paths
        for v in fm.get("related") or []:
            self.check_kb_path(file, "related[]", v)

    # --------------------------------------------------------- cross invariants

    def validate_crosslinks(self) -> None:
        # Every leaf (episodic entry, recipe, or model) must appear in its parent _route.md's entries[]
        for entry_path, entry_fm in {**self.entries, **self.recipes, **self.models}.items():
            parent_route = entry_path.parent / "_route.md"
            if parent_route not in self.routes:
                self.err(entry_path, f"parent folder has no _route.md at {parent_route}")
                continue
            route_entries = self.routes[parent_route].get("entries") or []
            entry_id = entry_fm.get("id")
            ids_in_route = [e.get("id") for e in route_entries if isinstance(e, dict)]
            if entry_id not in ids_in_route:
                self.err(parent_route, f"entries[] is missing leaf id={entry_id!r} (file: {entry_path.name})")

        # Every directory under KB_ROOT must have exactly one _route.md
        for dir_path in walk_dirs(KB_ROOT):
            route = dir_path / "_route.md"
            if not route.exists():
                self.err(dir_path, "directory has no _route.md")

        # Every subroute target must point at a _route.md that exists in our index
        for route_path, route_fm in self.routes.items():
            for sub in route_fm.get("subroutes") or []:
                if not isinstance(sub, dict):
                    continue
                target = self.kb_to_disk(sub.get("path") or "")
                if target and target.exists() and target not in self.routes:
                    self.err(route_path, f"subroutes[].path resolves but target route file isn't loaded: {sub.get('path')}")


def _is_hidden(rel: Path) -> bool:
    """Skip dot-prefixed dirs/files (.git, .librarian, .librarian.lock, etc)."""
    return any(part.startswith(".") for part in rel.parts)


def walk_dirs(root: Path):
    for p in root.rglob("*"):
        if p.is_dir() and not _is_hidden(p.relative_to(root)):
            yield p
    yield root  # include root itself


def walk_md(root: Path):
    for p in root.rglob("*.md"):
        if not _is_hidden(p.relative_to(root)):
            yield p


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quiet", action="store_true", help="only print errors")
    args = parser.parse_args()

    if not KB_ROOT.exists():
        print(f"KB_ROOT does not exist: {KB_ROOT}", file=sys.stderr)
        return 2

    v = Validator()

    file_count = 0
    for path in walk_md(KB_ROOT):
        file_count += 1
        fm = v.parse_frontmatter(path)
        if fm is None:
            continue
        if path.name == "_route.md":
            v.validate_route(path, fm)
        elif fm.get("type") == "recipe":
            v.validate_recipe(path, fm)
        elif fm.get("type") == "model":
            v.validate_model(path, fm)
        else:
            v.validate_entry(path, fm)

    v.validate_crosslinks()

    if v.errors:
        for path, msg in v.errors:
            try:
                rel = path.relative_to(KB_ROOT)
                pretty = f"kb:/{rel}"
            except ValueError:
                pretty = str(path)
            print(f"{pretty}: {msg}", file=sys.stderr)
        print(f"\n{len(v.errors)} error(s) across {file_count} file(s)", file=sys.stderr)
        return 1

    if not args.quiet:
        print(f"ok: {file_count} files, {len(v.routes)} routes, {len(v.entries)} entries, "
              f"{len(v.recipes)} recipes, {len(v.models)} models — schema clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
