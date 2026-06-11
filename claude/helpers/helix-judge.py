#!/usr/bin/env python3
"""helix-judge.py — M1 LLM-as-judge para conflictos semánticos

Backend: ollama local (D2 100% local, no cloud LLM in core).
Default model: llama3.2:3b (fast, accurate enough with few-shot prompt).

Modes:
  judge <A> <B>            Judge a single claim pair, print JSON result
  scan <jsonl_path> [-n N] Scan last N entries pairwise from a JSONL corpus
  audit-list [-n N]        Random N% sample of last decisions for human review
  audit-mark <id> ok|wrong Mark a decision as creator-validated; updates audit-feedback.jsonl
  stats                    Precision metrics (requires audit-marks)

Hard rules (acceptance criteria M1):
  - Confidence threshold ≥ 0.85 to emit non-trivial verdict
  - Audit log: 100% of judge calls go to ~/.claude/memory/judge-decisions.jsonl
  - Anti-poisoning (CS1): few-shot examples are STATIC in code; never updated
    from the judge's own decisions. Updates require manual edit + creator audit.
  - NO trigger of S1 auto-update (S1 is REJECTED in TRANCH 3 — defensive: code
    has no S1 hook even if S1 existed).

Audit feedback (CS1 calibration):
  ~/.claude/memory/judge-audit-feedback.jsonl tracks creator's labels of judge
  decisions (ok/wrong). This is the ONLY source for precision stats and the
  ONLY source the judge corpus may consume in future versions.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import secrets
import subprocess
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
# Respect CLAUDE_CONFIG_DIR (Helix migration to ~/.helix/). Falls back to ~/.claude.
CONFIG_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(HOME / ".claude")))
LOG = CONFIG_DIR / "memory/judge-decisions.jsonl"
FEEDBACK = CONFIG_DIR / "memory/judge-audit-feedback.jsonl"
DEFAULT_MODEL = os.environ.get("HELIX_JUDGE_MODEL", "llama3.2:3b")
CONFIDENCE_THRESHOLD = float(os.environ.get("HELIX_JUDGE_CONF", "0.85"))
OLLAMA_TIMEOUT_S = int(os.environ.get("HELIX_JUDGE_TIMEOUT", "60"))

# ─────────────────────────────────────────────────────────────────────────────
# STATIC few-shot prompt — anti-poisoning CS1: NEVER updated from judge output.
# Updates here require manual edit by creator and a code review entry.
# ─────────────────────────────────────────────────────────────────────────────
FEW_SHOT_PROMPT = """\
You are a strict semantic judge. Determine if two claims contradict each other.

EXAMPLES:

Claim A: "Default port is 8080"
Claim B: "The default port is 3000"
Result: {"verdict": "CONTRADICTORY", "confidence": 0.95, "reasoning": "Same property given two different values"}

Claim A: "Sky is blue"
Claim B: "Apples are red"
Result: {"verdict": "UNRELATED", "confidence": 0.95, "reasoning": "Claims are about different topics"}

Claim A: "API uses POST"
Claim B: "Endpoint accepts POST requests"
Result: {"verdict": "CONSISTENT", "confidence": 0.92, "reasoning": "Both claims agree on the same property"}

Claim A: "Cache TTL is 30 seconds"
Claim B: "Cache TTL was changed to 5 minutes"
Result: {"verdict": "CONTRADICTORY", "confidence": 0.88, "reasoning": "Same property given conflicting values across time"}

Claim A: "The function returns null on error"
Claim B: "On error, the function throws an exception"
Result: {"verdict": "CONTRADICTORY", "confidence": 0.90, "reasoning": "Same behavior described with incompatible mechanisms"}

OUTPUT FORMAT (strict JSON, no other text):
{"verdict": "CONTRADICTORY|CONSISTENT|UNRELATED", "confidence": 0.0-1.0, "reasoning": "..."}

NOW JUDGE THIS PAIR.

Claim A: {{CLAIM_A}}
Claim B: {{CLAIM_B}}
Result:"""


def _new_id() -> str:
    return f"{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}-{secrets.token_hex(4)}"


def _ollama_run(model: str, prompt: str) -> tuple[str, float]:
    """Returns (raw_output, elapsed_s). Raises on timeout/missing ollama."""
    t0 = time.time()
    try:
        proc = subprocess.run(
            ["ollama", "run", "--format", "json", model, prompt],
            capture_output=True,
            text=True,
            timeout=OLLAMA_TIMEOUT_S,
        )
    except FileNotFoundError:
        raise RuntimeError("ollama not found in PATH (D2 100% local — install ollama)")
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"ollama timeout {OLLAMA_TIMEOUT_S}s on model {model}")
    elapsed = time.time() - t0
    if proc.returncode != 0:
        raise RuntimeError(f"ollama failed: {proc.stderr.strip()[:200]}")
    return proc.stdout.strip(), elapsed


_VALID_VERDICTS = {"CONTRADICTORY", "CONSISTENT", "UNRELATED"}


def _parse_verdict(raw: str) -> dict | None:
    """Parse the model output into a structured verdict, or None if malformed."""
    # Try direct JSON first
    s = raw.strip()
    # Sometimes model prepends/appends text — try to extract first {...}
    m = re.search(r"\{[^{}]*\"verdict\"[^{}]*\}", s, re.DOTALL)
    if not m:
        return None
    try:
        d = json.loads(m.group(0))
    except Exception:
        return None
    v = str(d.get("verdict", "")).upper()
    if v not in _VALID_VERDICTS:
        return None
    try:
        c = float(d.get("confidence", 0))
    except Exception:
        c = 0.0
    c = max(0.0, min(1.0, c))
    return {"verdict": v, "confidence": c, "reasoning": str(d.get("reasoning", ""))[:300]}


def _log_decision(entry: dict) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    try:
        import fcntl
        with LOG.open("a", encoding="utf-8") as f:
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            except Exception:
                pass
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        try:
            with LOG.open("a", encoding="utf-8") as f:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception:
            pass


def _judge_pair(claim_a: str, claim_b: str, source: str = "manual",
                model: str = DEFAULT_MODEL) -> dict:
    """Run the judge and persist a decision entry. Returns the entry dict."""
    prompt = FEW_SHOT_PROMPT.replace("{{CLAIM_A}}", claim_a).replace("{{CLAIM_B}}", claim_b)
    raw, elapsed = _ollama_run(model, prompt)
    parsed = _parse_verdict(raw)
    decision_id = _new_id()
    if parsed is None:
        entry = {
            "id": decision_id,
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "model": model,
            "source": source,
            "claim_a": claim_a,
            "claim_b": claim_b,
            "verdict": "PARSE_ERROR",
            "confidence": 0.0,
            "reasoning": "",
            "raw": raw[:300],
            "elapsed_s": round(elapsed, 2),
            "emitted": False,  # below threshold (parse error)
        }
        _log_decision(entry)
        return entry

    emitted = (
        parsed["verdict"] != "UNRELATED"
        and parsed["confidence"] >= CONFIDENCE_THRESHOLD
    )
    entry = {
        "id": decision_id,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "model": model,
        "source": source,
        "claim_a": claim_a,
        "claim_b": claim_b,
        "verdict": parsed["verdict"],
        "confidence": parsed["confidence"],
        "reasoning": parsed["reasoning"],
        "elapsed_s": round(elapsed, 2),
        "emitted": emitted,
    }
    _log_decision(entry)
    return entry


# ─────────────────────────────────────────────────────────────────────────────
# CLI commands
# ─────────────────────────────────────────────────────────────────────────────

def cmd_judge(args: argparse.Namespace) -> int:
    entry = _judge_pair(args.claim_a, args.claim_b, source="manual",
                        model=args.model or DEFAULT_MODEL)
    out = {k: entry[k] for k in ("id", "verdict", "confidence", "emitted",
                                  "reasoning", "elapsed_s")}
    print(json.dumps(out, ensure_ascii=False, indent=2))
    if not entry["emitted"]:
        print(f"\n(below threshold {CONFIDENCE_THRESHOLD} or UNRELATED — logged but not emitted as alert)",
              file=sys.stderr)
    return 0


def cmd_scan(args: argparse.Namespace) -> int:
    path = Path(args.corpus)
    if not path.exists():
        print(f"corpus not found: {path}")
        return 2
    n = args.last
    lines: list[str] = []
    with path.open("r", encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                lines.append(ln)
    if not lines:
        print("(corpus empty)")
        return 0
    lines = lines[-n:]
    # Extract a "claim" from each line: prefer 'snippet', fallback 'claim', 'text', whole line
    def extract(s: str) -> str:
        try:
            d = json.loads(s)
            for k in ("snippet", "claim", "text", "summary"):
                v = d.get(k)
                if v:
                    return str(v)[:300]
            return json.dumps(d, ensure_ascii=False)[:300]
        except Exception:
            return s[:300]
    claims = [(i, extract(s)) for i, s in enumerate(lines)]

    print(f"scanning {len(claims)} entries pairwise = {len(claims)*(len(claims)-1)//2} pairs")
    print(f"model={args.model or DEFAULT_MODEL}  threshold={CONFIDENCE_THRESHOLD}\n")

    flagged = 0
    total = 0
    for i in range(len(claims)):
        for j in range(i + 1, len(claims)):
            total += 1
            a = claims[i][1]
            b = claims[j][1]
            entry = _judge_pair(a, b, source=f"scan:{path.name}:{i},{j}",
                                model=args.model or DEFAULT_MODEL)
            if entry["emitted"]:
                flagged += 1
                print(f"[{entry['verdict']} conf={entry['confidence']:.2f}] pair ({i},{j})")
                print(f"  A: {a[:120]}")
                print(f"  B: {b[:120]}")
                print(f"  reason: {entry['reasoning'][:160]}")
                print()
            if args.max_flags and flagged >= args.max_flags:
                print(f"\nstopped at {args.max_flags} flagged pairs")
                break
        if args.max_flags and flagged >= args.max_flags:
            break

    print(f"\nscan complete: {total} pairs, {flagged} emitted as conflicts")
    return 0


def cmd_audit_list(args: argparse.Namespace) -> int:
    if not LOG.exists():
        print("(no decisions yet)")
        return 0
    decisions = []
    with LOG.open("r", encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                decisions.append(json.loads(ln))
            except Exception:
                continue
    decisions = [d for d in decisions if d.get("emitted")]
    if not decisions:
        print("(no emitted decisions to audit)")
        return 0
    sample_n = max(1, int(len(decisions) * args.sample_pct / 100))
    sample = random.sample(decisions, min(sample_n, len(decisions)))
    print(f"{len(sample)} decisions sampled ({args.sample_pct}% of {len(decisions)} emitted):\n")
    for d in sample:
        print(f"[{d['id']}] {d['verdict']} conf={d['confidence']:.2f}")
        print(f"  A: {d['claim_a'][:120]}")
        print(f"  B: {d['claim_b'][:120]}")
        print(f"  reason: {d['reasoning'][:140]}")
        print()
    print(f"To label: helix-judge.py audit-mark <id> ok|wrong")
    return 0


def cmd_audit_mark(args: argparse.Namespace) -> int:
    if args.label not in ("ok", "wrong"):
        print(f"label must be 'ok' or 'wrong', got: {args.label}")
        return 2
    FEEDBACK.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "decision_id": args.decision_id,
        "label": args.label,
        "note": args.note or "",
    }
    with FEEDBACK.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print(f"marked {args.decision_id} = {args.label}")
    return 0


def cmd_stats(_: argparse.Namespace) -> int:
    if not FEEDBACK.exists():
        print("(no audit feedback yet — use audit-list + audit-mark first)")
        return 0
    ok = wrong = 0
    by_id: dict[str, str] = {}
    with FEEDBACK.open("r", encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln: continue
            try:
                e = json.loads(ln)
            except Exception:
                continue
            by_id[e["decision_id"]] = e["label"]  # last label wins
    for label in by_id.values():
        if label == "ok":
            ok += 1
        elif label == "wrong":
            wrong += 1
    total = ok + wrong
    if total == 0:
        print("(no labeled decisions)")
        return 0
    precision = 100.0 * ok / total
    print(f"labeled: {total}  ok: {ok}  wrong: {wrong}")
    print(f"precision (ok / labeled): {precision:5.1f}%   target ≥70%   "
          f"{'PASS' if precision >= 70 else 'FAIL'}")
    print(f"noise     (wrong / labeled): {100*wrong/total:5.1f}%   target ≤30%   "
          f"{'PASS' if 100*wrong/total <= 30 else 'FAIL'}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="helix-judge")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_j = sub.add_parser("judge", help="judge a single claim pair")
    p_j.add_argument("claim_a")
    p_j.add_argument("claim_b")
    p_j.add_argument("--model")
    p_j.set_defaults(func=cmd_judge)

    p_s = sub.add_parser("scan", help="scan a JSONL corpus pairwise")
    p_s.add_argument("corpus")
    p_s.add_argument("-n", "--last", type=int, default=20,
                     help="number of last entries to consider (default 20)")
    p_s.add_argument("--max-flags", type=int, default=0,
                     help="stop after N emitted conflicts (0 = no cap)")
    p_s.add_argument("--model")
    p_s.set_defaults(func=cmd_scan)

    p_al = sub.add_parser("audit-list", help="random sample of emitted decisions for human review")
    p_al.add_argument("--sample-pct", type=int, default=20)
    p_al.set_defaults(func=cmd_audit_list)

    p_am = sub.add_parser("audit-mark", help="label a decision as ok or wrong")
    p_am.add_argument("decision_id")
    p_am.add_argument("label", choices=["ok", "wrong"])
    p_am.add_argument("--note")
    p_am.set_defaults(func=cmd_audit_mark)

    p_st = sub.add_parser("stats", help="precision/noise from audit feedback")
    p_st.set_defaults(func=cmd_stats)

    args = ap.parse_args()
    try:
        return args.func(args)
    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 4


if __name__ == "__main__":
    sys.exit(main())
