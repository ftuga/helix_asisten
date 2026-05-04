#!/usr/bin/env python3
"""helix-aidefence-hook.py — SEC1 PII redact (v1.0)

PostToolUse(Write|Edit|MultiEdit). Always exit 0. NEVER blocks (hard rule).

Scope acotado v1.0 (anti-circularidad CS2):
  - Aplica SOLO a logs/audit/snapshot internos de Helix
  - Targets: ~/.claude/memory/*.jsonl, helix-bitacora*.md, snapshots/*.yaml,
             routing-feedback.jsonl, injection-alerts.jsonl, council/log/*.yaml
  - NO aplica a archivos del proyecto del usuario (responsabilidad usuario)

Acción: redact in place con [PII:<type>]. NO block.
Audit log: ~/.claude/memory/aidefence-redactions.jsonl (que también se autoredacta-skip).

PII types cubiertos (10+, sin overlap con HSL L3 secrets):
  EMAIL, PHONE_E164, PHONE_NA, SSN_US, IBAN, IPV4_PUBLIC, IPV6_PUBLIC,
  CREDIT_CARD (Luhn-validated), PATH_USERNAME_LINUX, PATH_USERNAME_WINDOWS,
  URL_USERINFO
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
REDACTION_LOG = HOME / ".claude/memory/aidefence-redactions.jsonl"
MAX_FILE_SIZE = 1 * 1024 * 1024  # 1 MB cap (logs above this should rotate)

# ─────────────────────────────────────────────────────────────────────────────
# SCOPE — hard rule. Hook only acts on these paths.
# ─────────────────────────────────────────────────────────────────────────────
SCOPE_PATTERNS = [
    re.compile(r"^.+/\.claude/memory/[^/]*\.jsonl$"),
    re.compile(r"^.+/\.claude/memory/helix-bitacora.*\.md$"),
    re.compile(r"^.+/\.claude/memory/routing-feedback\.jsonl$"),
    re.compile(r"^.+/\.claude/memory/injection-alerts\.jsonl$"),
    re.compile(r"^.+/\.claude/memory/passive-captures-.*\.jsonl$"),
    re.compile(r"^.+/\.claude/memory/egress-audit\.jsonl$"),
    re.compile(r"^.+/\.claude/snapshots/[^/]+\.ya?ml$"),
    re.compile(r"^.+/\.claude/council/log/.*\.yaml$"),
]

# Paths where the hook MUST NOT act even if scope match would suggest otherwise
# (anti-recursion: redaction log itself).
SCOPE_DENY = [
    re.compile(r".*/aidefence-redactions\.jsonl$"),
]

# ─────────────────────────────────────────────────────────────────────────────
# PII PATTERNS
# ─────────────────────────────────────────────────────────────────────────────
# Each: (label, compiled regex, optional validator). Order matters: more
# specific first (CREDIT_CARD before phone, IBAN before generic).

EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b")
PHONE_E164_RE = re.compile(r"\+\d{1,3}[\s\-]?\(?\d{1,4}\)?[\s\-]?\d{2,4}[\s\-]?\d{2,4}[\s\-]?\d{0,4}")
PHONE_NA_RE = re.compile(r"\(\d{3}\)\s?\d{3}[\s\-\.]?\d{4}|(?<!\d)\d{3}[\s\-\.]\d{3}[\s\-\.]\d{4}(?!\d)")
SSN_US_RE = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
IBAN_RE = re.compile(r"\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b")
IPV4_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
# IPv6 — handles full, compressed (::), and mixed forms; greedy enough to grab full address
IPV6_RE = re.compile(
    r"(?<![:\w])"
    r"(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}"
    r"|(?:[0-9a-fA-F]{1,4}:){1,7}(?::[0-9a-fA-F]{1,4})+"
    r"|(?:[0-9a-fA-F]{1,4}:){1,7}:"
    r"|::(?:[0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}"
    r"(?![:\w])"
)
CC_RE = re.compile(r"\b(?:\d[ \-]?){13,19}\b")
PATH_LINUX_RE = re.compile(r"(?:/home|/Users)/([A-Za-z0-9_.\-]+)/")
PATH_WINDOWS_RE = re.compile(r"[Cc]:\\Users\\([A-Za-z0-9_.\- ]+)\\")
URL_USERINFO_RE = re.compile(r"https?://[^/\s:]+:[^/@\s]+@")


def _is_private_ipv4(addr: str) -> bool:
    try:
        parts = [int(p) for p in addr.split(".")]
        if len(parts) != 4 or any(p < 0 or p > 255 for p in parts):
            return True  # malformed — treat as non-public, skip
        a, b = parts[0], parts[1]
        if a == 10:
            return True
        if a == 127:
            return True
        if a == 172 and 16 <= b <= 31:
            return True
        if a == 192 and b == 168:
            return True
        if a == 169 and b == 254:
            return True
        if a == 0:
            return True
        if a >= 224:  # multicast / reserved
            return True
        return False
    except Exception:
        return True


def _luhn_valid(num: str) -> bool:
    digits = [int(c) for c in re.sub(r"[^0-9]", "", num)]
    if len(digits) < 13 or len(digits) > 19:
        return False
    s = 0
    parity = len(digits) % 2
    for i, d in enumerate(digits):
        if i % 2 == parity:
            d *= 2
            if d > 9:
                d -= 9
        s += d
    return s % 10 == 0


def _is_loopback_or_unspec_ipv6(addr: str) -> bool:
    a = addr.lower()
    if a == "::" or a == "::1":
        return True
    if a.startswith("fe80:") or a.startswith("fc") or a.startswith("fd"):
        return True
    return False


# ─────────────────────────────────────────────────────────────────────────────
# REDACTION ENGINE
# ─────────────────────────────────────────────────────────────────────────────

def _redact_text(text: str) -> tuple[str, dict[str, int]]:
    """Apply patterns, return (redacted, counts_by_type)."""
    counts: dict[str, int] = {}

    def bump(label: str, n: int = 1) -> None:
        counts[label] = counts.get(label, 0) + n

    # CREDIT_CARD with Luhn — replace per-match
    def cc_sub(m: re.Match[str]) -> str:
        if _luhn_valid(m.group(0)):
            bump("CREDIT_CARD")
            return "[PII:CREDIT_CARD]"
        return m.group(0)
    text = CC_RE.sub(cc_sub, text)

    # IBAN
    def iban_sub(m: re.Match[str]) -> str:
        bump("IBAN")
        return "[PII:IBAN]"
    text = IBAN_RE.sub(iban_sub, text)

    # SSN
    def ssn_sub(m: re.Match[str]) -> str:
        bump("SSN_US")
        return "[PII:SSN_US]"
    text = SSN_US_RE.sub(ssn_sub, text)

    # PHONE E.164
    def phone_e164_sub(m: re.Match[str]) -> str:
        bump("PHONE_E164")
        return "[PII:PHONE_E164]"
    text = PHONE_E164_RE.sub(phone_e164_sub, text)

    # PHONE NA — only after E.164 to avoid double-match
    def phone_na_sub(m: re.Match[str]) -> str:
        bump("PHONE_NA")
        return "[PII:PHONE_NA]"
    text = PHONE_NA_RE.sub(phone_na_sub, text)

    # URL_USERINFO BEFORE EMAIL — userinfo's `pass@host` would otherwise be matched as email
    def urluser_sub(m: re.Match[str]) -> str:
        bump("URL_USERINFO")
        end = m.group(0)
        scheme = "https://" if end.startswith("https") else "http://"
        return f"{scheme}[PII:URL_USERINFO]@"
    text = URL_USERINFO_RE.sub(urluser_sub, text)

    # EMAIL
    def email_sub(m: re.Match[str]) -> str:
        bump("EMAIL")
        return "[PII:EMAIL]"
    text = EMAIL_RE.sub(email_sub, text)

    # IPv4 — only redact if public
    def ipv4_sub(m: re.Match[str]) -> str:
        addr = m.group(0)
        if _is_private_ipv4(addr):
            return addr
        bump("IPV4_PUBLIC")
        return "[PII:IPV4_PUBLIC]"
    text = IPV4_RE.sub(ipv4_sub, text)

    # IPv6
    def ipv6_sub(m: re.Match[str]) -> str:
        if _is_loopback_or_unspec_ipv6(m.group(0)):
            return m.group(0)
        bump("IPV6_PUBLIC")
        return "[PII:IPV6_PUBLIC]"
    text = IPV6_RE.sub(ipv6_sub, text)

    # PATH username (Linux / macOS)
    def path_lx_sub(m: re.Match[str]) -> str:
        bump("PATH_USERNAME")
        prefix = m.group(0).split("/")[1]  # "home" or "Users"
        return f"/{prefix}/[PII:USERNAME]/"
    text = PATH_LINUX_RE.sub(path_lx_sub, text)

    # PATH username (Windows)
    def path_win_sub(m: re.Match[str]) -> str:
        bump("PATH_USERNAME")
        return r"C:\Users\[PII:USERNAME]\\"
    text = PATH_WINDOWS_RE.sub(path_win_sub, text)

    return text, counts


# ─────────────────────────────────────────────────────────────────────────────
# HOOK MAIN
# ─────────────────────────────────────────────────────────────────────────────

def _in_scope(path: str) -> bool:
    for deny in SCOPE_DENY:
        if deny.match(path):
            return False
    for pat in SCOPE_PATTERNS:
        if pat.match(path):
            return True
    return False


def _log_redaction(file_path: str, counts: dict[str, int], tool: str) -> None:
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "file": file_path,
        "tool": tool,
        "counts": counts,
        "total": sum(counts.values()),
    }
    REDACTION_LOG.parent.mkdir(parents=True, exist_ok=True)
    try:
        import fcntl
        with REDACTION_LOG.open("a", encoding="utf-8") as f:
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            except Exception:
                pass
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        try:
            with REDACTION_LOG.open("a", encoding="utf-8") as f:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception:
            pass


def main() -> int:
    try:
        raw = sys.stdin.read() or "{}"
        data = json.loads(raw)
    except Exception:
        return 0

    tool = data.get("tool_name") or data.get("tool") or ""
    if tool not in ("Edit", "Write", "MultiEdit"):
        return 0

    ti = data.get("tool_input") or {}
    file_path = ti.get("file_path") or ""
    if not file_path:
        return 0

    # Hard rule: scope acotado
    if not _in_scope(file_path):
        return 0

    p = Path(file_path)
    if not p.exists() or not p.is_file():
        return 0
    try:
        if p.stat().st_size > MAX_FILE_SIZE:
            return 0
        original = p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return 0

    redacted, counts = _redact_text(original)
    if not counts:
        return 0
    if redacted == original:
        return 0

    try:
        p.write_text(redacted, encoding="utf-8")
    except Exception:
        return 0

    _log_redaction(file_path, counts, tool)

    summary = ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    print(f"[SEC1] redacted {sum(counts.values())} PII matches in {p.name}: {summary}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
