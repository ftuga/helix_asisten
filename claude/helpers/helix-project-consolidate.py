#!/usr/bin/env python3
"""helix-project-consolidate.py — M3 drift de nombres detector + unify

Modes:
  scan [--target DIR ...]                List candidate name-drift pairs
  report [--target DIR ...]              Same as scan, markdown output
  unify <pair_id> [--keep 1|2|merge]     Interactive merge for one pair
  list                                   Show last scan's pairs with ids

Acceptance criteria (M3):
  - Detection of real drift ≥80%               (creator review)
  - Interactive prompt obligatorio             (NEVER unifies without OK)
  - Reversibilidad (git revert si en repo)     (smoke test)
  - Fuzzy threshold env var ajustable          (HELIX_M3_FUZZY_THRESHOLD)

Default targets:
  ~/.claude/helpers
  ~/.claude/memory/agents
  ~/.claude/memory/topics
  ~/.claude/skills (one level deep, dir names)

Hard rule: unify NEVER applies changes without explicit `[y/N]` confirmation.
Every apply step prints the planned mv/rm operations first.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, asdict
from pathlib import Path

THRESHOLD = float(os.environ.get("HELIX_M3_FUZZY_THRESHOLD", "0.75"))
HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
# Respect CLAUDE_CONFIG_DIR (Helix migration to ~/.helix/). Falls back to ~/.claude.
CONFIG_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(HOME / ".claude")))
STATE_PATH = CONFIG_DIR / "memory/.m3-last-scan.json"
BACKUP_DIR = CONFIG_DIR / "backups/m3"

DEFAULT_TARGETS = [
    CONFIG_DIR / "helpers",
    CONFIG_DIR / "memory/agents",
    CONFIG_DIR / "memory/topics",
    CONFIG_DIR / "skills",
]


@dataclass
class Pair:
    pair_id: str
    a: str
    b: str
    ratio: float
    a_size: int
    b_size: int
    a_mtime: str
    b_mtime: str
    same_dir: bool


def _list_files(target: Path) -> list[Path]:
    if not target.exists():
        return []
    if target == CONFIG_DIR / "skills":
        # Skills are subdirs; treat dir names as comparable units
        return sorted(p for p in target.iterdir() if p.is_dir() and not p.name.startswith("_"))
    return sorted(
        p for p in target.iterdir()
        if p.is_file() and not p.name.startswith(".")
    )


def _name_key(p: Path) -> str:
    """Normalised name for similarity (drop common prefix/suffix)."""
    n = p.stem if p.is_file() else p.name
    n = n.lower()
    for prefix in ("helix-", "helix_", "claude-"):
        if n.startswith(prefix):
            n = n[len(prefix):]
            break
    for suffix in ("-hook", "_hook", "-helper"):
        if n.endswith(suffix):
            n = n[: -len(suffix)]
            break
    return n


def _hash_pair(a: Path, b: Path) -> str:
    raw = "|".join(sorted([str(a), str(b)]))
    return hashlib.sha1(raw.encode()).hexdigest()[:8]


def _stat(p: Path) -> tuple[int, str]:
    try:
        st = p.stat()
        return st.st_size, time.strftime("%Y-%m-%d", time.localtime(st.st_mtime))
    except Exception:
        return 0, "?"


def scan(targets: list[Path]) -> list[Pair]:
    pairs: list[Pair] = []
    for tgt in targets:
        files = _list_files(tgt)
        keys = [(p, _name_key(p)) for p in files]
        for i in range(len(keys)):
            pa, ka = keys[i]
            for j in range(i + 1, len(keys)):
                pb, kb = keys[j]
                if not ka or not kb:
                    continue
                ratio = difflib.SequenceMatcher(None, ka, kb).ratio()
                if ratio < THRESHOLD:
                    continue
                # Skip identical name keys with different extensions only if both
                # are scripts that actually differ in suffix (.py vs .sh wrappers)
                # — leave to creator to decide; report all.
                a_size, a_mtime = _stat(pa)
                b_size, b_mtime = _stat(pb)
                pairs.append(
                    Pair(
                        pair_id=_hash_pair(pa, pb),
                        a=str(pa),
                        b=str(pb),
                        ratio=round(ratio, 3),
                        a_size=a_size,
                        b_size=b_size,
                        a_mtime=a_mtime,
                        b_mtime=b_mtime,
                        same_dir=True,
                    )
                )
    pairs.sort(key=lambda p: (-p.ratio, p.a))
    return pairs


def _save_state(pairs: list[Pair]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(
        json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "threshold": THRESHOLD,
                    "pairs": [asdict(p) for p in pairs]}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _load_state() -> dict:
    if not STATE_PATH.exists():
        return {"pairs": []}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {"pairs": []}


def cmd_scan(args: argparse.Namespace) -> int:
    targets = [Path(t) for t in args.target] if args.target else DEFAULT_TARGETS
    pairs = scan(targets)
    _save_state(pairs)
    if not pairs:
        print(f"no pairs ≥ threshold {THRESHOLD}")
        return 0
    print(f"{len(pairs)} candidate pair(s) (threshold ≥ {THRESHOLD}):\n")
    for p in pairs:
        a_short = p.a.replace(str(HOME), "~")
        b_short = p.b.replace(str(HOME), "~")
        print(f"  [{p.pair_id}] ratio={p.ratio}")
        print(f"    A: {a_short}  ({p.a_size}b, {p.a_mtime})")
        print(f"    B: {b_short}  ({p.b_size}b, {p.b_mtime})")
        print()
    print(f"State saved to {STATE_PATH.relative_to(HOME) if STATE_PATH.is_relative_to(HOME) else STATE_PATH}")
    print(f"Run: helix-project-consolidate.py unify <pair_id>  to review and merge.")
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    targets = [Path(t) for t in args.target] if args.target else DEFAULT_TARGETS
    pairs = scan(targets)
    _save_state(pairs)
    print(f"# M3 drift scan — {time.strftime('%Y-%m-%d %H:%M', time.localtime())}\n")
    print(f"Threshold: ≥{THRESHOLD}\n")
    print(f"Targets: {', '.join(str(t) for t in targets)}\n")
    if not pairs:
        print("No candidate pairs found.\n")
        return 0
    print(f"## Candidate pairs ({len(pairs)})\n")
    print("| pair_id | ratio | A | B | sizes (a/b) | mtimes (a/b) |")
    print("|---|---|---|---|---|---|")
    for p in pairs:
        a_short = p.a.replace(str(HOME), "~")
        b_short = p.b.replace(str(HOME), "~")
        print(f"| `{p.pair_id}` | {p.ratio} | `{a_short}` | `{b_short}` | {p.a_size}/{p.b_size} | {p.a_mtime}/{p.b_mtime} |")
    return 0


def cmd_list(_: argparse.Namespace) -> int:
    state = _load_state()
    pairs = state.get("pairs") or []
    if not pairs:
        print("(no scan state — run `scan` first)")
        return 0
    print(f"last scan: {state.get('ts','?')}  threshold: {state.get('threshold','?')}\n")
    for p in pairs:
        a_short = p["a"].replace(str(HOME), "~")
        b_short = p["b"].replace(str(HOME), "~")
        print(f"  [{p['pair_id']}] {p['ratio']}  {a_short}  vs  {b_short}")
    return 0


def _is_git_repo(p: Path) -> bool:
    cur = p if p.is_dir() else p.parent
    while cur != cur.parent:
        if (cur / ".git").exists():
            return True
        cur = cur.parent
    return False


def _show_diff(a: Path, b: Path) -> None:
    try:
        a_lines = a.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
        b_lines = b.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    except Exception:
        print(f"(could not diff binary or unreadable file)")
        return
    diff = difflib.unified_diff(a_lines, b_lines, fromfile=str(a), tofile=str(b), lineterm="", n=3)
    out = list(diff)
    if not out:
        print("(files are identical)")
    else:
        print("".join(out[:200]))
        if len(out) > 200:
            print(f"\n... [truncated, {len(out)-200} more lines]")


def _backup(p: Path, ts: str) -> Path:
    rel = p.relative_to(HOME) if p.is_relative_to(HOME) else Path(p.name)
    dest = BACKUP_DIR / ts / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    if p.is_dir():
        shutil.copytree(p, dest)
    else:
        shutil.copy2(p, dest)
    return dest


def cmd_unify(args: argparse.Namespace) -> int:
    state = _load_state()
    pairs = state.get("pairs") or []
    pair = next((p for p in pairs if p["pair_id"] == args.pair_id), None)
    if not pair:
        print(f"pair_id not found: {args.pair_id}")
        print("Run `scan` first to refresh state.")
        return 2

    a = Path(pair["a"])
    b = Path(pair["b"])
    if not a.exists() or not b.exists():
        print(f"one of the paths no longer exists; rerun scan")
        return 3

    print(f"Pair {pair['pair_id']}  ratio={pair['ratio']}")
    print(f"  A: {a}  ({pair['a_size']}b, {pair['a_mtime']})")
    print(f"  B: {b}  ({pair['b_size']}b, {pair['b_mtime']})")
    print()
    if a.is_file() and b.is_file():
        print("--- diff (A → B) ---")
        _show_diff(a, b)
        print("--- end diff ---\n")
    else:
        print("(directory pair — diff suppressed; review manually)\n")

    decision = (args.keep or "").lower()
    if not decision:
        print("Decision: [1]=keep A delete B  [2]=keep B delete A  [s]=skip  [q]=quit")
        try:
            decision = input("> ").strip().lower()
        except EOFError:
            print("(non-interactive: aborting)")
            return 4
    if decision in ("s", "skip"):
        print("skipped")
        return 0
    if decision in ("q", "quit", ""):
        print("aborted")
        return 0
    if decision not in ("1", "2"):
        print(f"invalid decision: {decision!r}")
        return 5

    keep, drop = (a, b) if decision == "1" else (b, a)
    in_git = _is_git_repo(drop)
    ts = time.strftime("%Y%m%d-%H%M%S", time.localtime())

    print("\nPlanned actions:")
    print(f"  keep  : {keep}")
    print(f"  remove: {drop}")
    if in_git:
        print(f"  method: git rm   (revert via `git restore`/`git revert`)")
    else:
        print(f"  method: backup → rm   (backup at {BACKUP_DIR / ts})")

    confirm = (args.yes and "y") or ""
    if not confirm:
        try:
            confirm = input("APPLY? [y/N] ").strip().lower()
        except EOFError:
            confirm = ""
    if confirm != "y":
        print("not applied")
        return 0

    try:
        if in_git:
            subprocess.run(["git", "rm", "-rf", str(drop)], check=True, cwd=str(drop.parent))
        else:
            backup_path = _backup(drop, ts)
            print(f"backed up → {backup_path}")
            if drop.is_dir():
                shutil.rmtree(drop)
            else:
                drop.unlink()
        print(f"OK: {drop} removed; kept {keep}")
        return 0
    except Exception as e:
        print(f"ERROR applying: {e}")
        return 6


def main() -> int:
    ap = argparse.ArgumentParser(prog="helix-project-consolidate")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_scan = sub.add_parser("scan", help="list candidate drift pairs")
    p_scan.add_argument("--target", action="append", help="override default target dirs")
    p_scan.set_defaults(func=cmd_scan)

    p_rep = sub.add_parser("report", help="markdown report of drift")
    p_rep.add_argument("--target", action="append")
    p_rep.set_defaults(func=cmd_report)

    p_list = sub.add_parser("list", help="show last scan results")
    p_list.set_defaults(func=cmd_list)

    p_uni = sub.add_parser("unify", help="interactive merge for one pair")
    p_uni.add_argument("pair_id")
    p_uni.add_argument("--keep", choices=["1", "2"], help="non-interactive choice")
    p_uni.add_argument("--yes", "-y", action="store_true", help="non-interactive apply")
    p_uni.set_defaults(func=cmd_unify)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
