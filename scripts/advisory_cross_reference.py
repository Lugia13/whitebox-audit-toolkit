#!/usr/bin/env python3
"""
advisory_cross_reference.py

Standalone, dependency-free (stdlib-only on Python 3.11+) cross-reference of one or
more Cargo.lock files against a local clone of the RustSec Advisory Database.

Use this as a fallback when `cargo-audit` can't be installed (toolchain/MSRV
mismatch, no network access to crates.io, sandboxed environment, etc.) but you can
still clone a plain git repository.

Setup:
    git clone --depth 1 https://github.com/RustSec/advisory-db.git

Usage:
    python3 advisory_cross_reference.py [advisory-db path] [Cargo.lock paths...]

    # Example: scan every Cargo.lock under several project directories
    python3 advisory_cross_reference.py advisory-db \
        project-a/**/Cargo.lock project-b/Cargo.lock

Notes on accuracy:
    The semver constraint matching here is intentionally simple (handles >=, <=, >,
    <, =, and bare "^"-style version prefixes, comma-separated). It is sufficient to
    triage candidates but is NOT a full semver implementation — always verify a hit
    manually against the advisory's published `patched`/`unaffected` ranges before
    treating it as confirmed. The goal of this script is to narrow a large dependency
    tree down to a short list worth looking at by hand, not to be a final authority.
"""

import re
import sys
import glob
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore


def load_advisories(advisory_db_path: str) -> list[dict]:
    """Parse every advisory .md file's TOML frontmatter block."""
    advisories = []
    pattern = str(Path(advisory_db_path) / "crates" / "*" / "*.md")
    for path in glob.glob(pattern):
        text = Path(path).read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"^```toml\n(.*?)\n```", text, re.S | re.M)
        if not match:
            continue
        try:
            data = tomllib.loads(match.group(1))
        except Exception:
            continue
        adv = data.get("advisory", {})
        versions = data.get("versions", {})
        advisories.append(
            {
                "package": adv.get("package"),
                "id": adv.get("id"),
                "title": adv.get("title"),
                "categories": adv.get("categories", []),
                "patched": versions.get("patched", []),
                "unaffected": versions.get("unaffected", []),
                "url": adv.get("url", ""),
            }
        )
    return advisories


def version_tuple(v: str) -> tuple[int, int, int]:
    v = v.split("-")[0].split("+")[0]
    parts = []
    for p in v.split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])  # type: ignore


def satisfies(version: str, constraint: str) -> bool:
    """Rough semver-range check: supports >=, <=, >, <, =, and bare '^'-style prefixes."""
    v = version_tuple(version)
    for part in constraint.split(","):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"^(>=|<=|>|<|=|\^)?\s*([\d.]+.*)$", part)
        if not m:
            continue
        op, cv = m.group(1) or "^", m.group(2)
        cvt = version_tuple(cv)
        if op == ">=" and not (v >= cvt):
            return False
        if op == "<=" and not (v <= cvt):
            return False
        if op == ">" and not (v > cvt):
            return False
        if op == "<" and not (v < cvt):
            return False
        if op == "=" and not (v == cvt):
            return False
        if op == "^" and not (v >= cvt and v[0] == cvt[0]):
            return False
    return True


def is_affected(version: str, advisory: dict) -> bool:
    for c in advisory["unaffected"]:
        if satisfies(version, c):
            return False
    for c in advisory["patched"]:
        if satisfies(version, c):
            return False
    return True


def scan_lockfiles(lockfile_paths: list[str], advisories: list[dict]) -> dict:
    findings: dict[tuple[str, str, str], set[str]] = {}
    for lockpath in lockfile_paths:
        try:
            data = tomllib.loads(Path(lockpath).read_text(encoding="utf-8", errors="ignore"))
        except Exception as e:
            print(f"[skip] failed to parse {lockpath}: {e}", file=sys.stderr)
            continue
        for pkg in data.get("package", []):
            name, version = pkg.get("name"), pkg.get("version")
            if not name or not version:
                continue
            for adv in advisories:
                if adv["package"] != name:
                    continue
                if is_affected(version, adv):
                    key = (name, version, adv["id"])
                    findings.setdefault(key, set()).add(lockpath)
    return findings


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    advisory_db_path, lockfile_globs = sys.argv[1], sys.argv[2:]
    lockfile_paths = [p for g in lockfile_globs for p in glob.glob(g, recursive=True)]

    advisories = load_advisories(advisory_db_path)
    print(f"Loaded {len(advisories)} advisories from {advisory_db_path}", file=sys.stderr)
    print(f"Scanning {len(lockfile_paths)} lockfile(s)", file=sys.stderr)

    findings = scan_lockfiles(lockfile_paths, advisories)
    print(f"\n=== {len(findings)} potentially affected (package, version, advisory) combos ===\n")

    for (name, version, advisory_id), locks in sorted(findings.items()):
        adv = next(a for a in advisories if a["id"] == advisory_id)
        categories = ", ".join(adv["categories"]) if adv["categories"] else "uncategorized"
        print(f"{advisory_id}  {name} {version}  [{categories}]")
        if adv["title"]:
            print(f"  title: {adv['title']}")
        print(f"  url: {adv['url']}")
        print(f"  in: {', '.join(sorted(locks))}")
        print()


if __name__ == "__main__":
    main()
