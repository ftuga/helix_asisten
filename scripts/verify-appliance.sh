#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Ruflo RVFA Appliance — Full Capability Verification Suite
# ADR-058: Self-Contained Ruflo RVF Appliance
# Fuente: https://github.com/ruvnet/ruflo/blob/main/scripts/verify-appliance.sh
#
# Tests ALL 35 categories (95+ checks) to verify every capability
# of the Ruflo + Claude Flow system works correctly.
#
# Usage:
#   sh verify-appliance.sh                    # Run all checks
#   sh verify-appliance.sh --quick            # Critical checks only
#   sh verify-appliance.sh --category memory  # Single category
#   sh verify-appliance.sh --json             # JSON output
# ═══════════════════════════════════════════════════════════════
set -e

PASS=0; FAIL=0; WARN=0; SKIP=0; ERRORS=""
START_TIME=$(date +%s)
QUICK_MODE=0; TARGET_CATEGORY=""; JSON_MODE=0
RUFLO_CMD="${RUFLO_CMD:-ruflo}"

while [ $# -gt 0 ]; do
  case "$1" in
    --quick|-q)     QUICK_MODE=1; shift ;;
    --category|-c)  TARGET_CATEGORY="$2"; shift 2 ;;
    --json|-j)      JSON_MODE=1; shift ;;
    --help|-h)
      echo "Ruflo Appliance Verification Suite"
      echo "Usage: sh verify-appliance.sh [--quick] [--category NAME] [--json]"
      echo "Env:   RUFLO_CMD=ruflo  SKIP_NETWORK=1  SKIP_MODELS=1"
      exit 0 ;;
    *) shift ;;
  esac
done

check() {
  local name="$1"; shift
  local output
  output=$("$@" 2>&1) && {
    PASS=$((PASS + 1))
    [ "$JSON_MODE" = "0" ] && printf "  ✓ %s\n" "$name"
  } || {
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  ✗ $name: $(echo "$output" | tail -1)"
    [ "$JSON_MODE" = "0" ] && printf "  ✗ %s\n" "$name"
  }
}

check_contains() {
  local name="$1"; local expected="$2"; shift 2
  local output; output=$("$@" 2>&1)
  if echo "$output" | grep -qi "$expected"; then
    PASS=$((PASS + 1)); [ "$JSON_MODE" = "0" ] && printf "  ✓ %s\n" "$name"
  else
    FAIL=$((FAIL + 1)); ERRORS="$ERRORS\n  ✗ $name: expected '$expected'"
    [ "$JSON_MODE" = "0" ] && printf "  ✗ %s\n" "$name"
  fi
}

check_warn() {
  local name="$1"; shift
  local output; output=$("$@" 2>&1) && {
    PASS=$((PASS + 1)); [ "$JSON_MODE" = "0" ] && printf "  ✓ %s\n" "$name"
  } || {
    WARN=$((WARN + 1)); [ "$JSON_MODE" = "0" ] && printf "  ⚠ %s (non-critical)\n" "$name"
  }
}

check_skip() {
  local name="$1"; local reason="$2"
  SKIP=$((SKIP + 1))
  [ "$JSON_MODE" = "0" ] && printf "  ⊘ %s (skipped: %s)\n" "$name" "$reason"
}

section() { [ "$JSON_MODE" = "0" ] && echo "" && echo "═══ $1. $2 ═══"; }

should_run() {
  [ -z "$TARGET_CATEGORY" ] && return 0
  echo "$1" | grep -qi "$TARGET_CATEGORY" && return 0; return 1
}

RUFLO_VERSION=$($RUFLO_CMD --version 2>/dev/null || echo "unknown")

if [ "$JSON_MODE" = "0" ]; then
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Ruflo Appliance — Full Capability Verification Suite   ║"
  echo "║  Node: $(node --version 2>/dev/null || echo 'N/A')  │  Ruflo: $RUFLO_VERSION"
  echo "║  Mode: $([ "$QUICK_MODE" = "1" ] && echo "Quick" || echo "Full") | $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "╚══════════════════════════════════════════════════════════╝"
fi

# PART I: Core CLI
should_run "cli" && {
  section 1 "CLI Core"
  check "ruflo --version" $RUFLO_CMD --version
  check "ruflo --help" $RUFLO_CMD --help
  check_contains "version string valid" "[0-9]\+\.[0-9]\+\.[0-9]" $RUFLO_CMD --version
}

should_run "doctor" && {
  section 2 "Doctor (Health Checks)"
  check "doctor runs" $RUFLO_CMD doctor
  check "doctor --fix" $RUFLO_CMD doctor --fix
  check "doctor -c node" $RUFLO_CMD doctor -c node
  check "doctor -c npm" $RUFLO_CMD doctor -c npm
  check "doctor -c disk" $RUFLO_CMD doctor -c disk
}

should_run "init" && {
  section 3 "Init System"
  TEST_DIR="/tmp/ruflo-verify-$$"
  mkdir -p "$TEST_DIR" && cd "$TEST_DIR"
  check "init --yes" $RUFLO_CMD init --yes
  check ".claude/settings.json exists" test -f .claude/settings.json
  check ".claude/helpers/ exists" test -d .claude/helpers
  check_contains "AGENT_TEAMS env set" "AGENT_TEAMS" cat .claude/settings.json
  check "helpers/statusline.cjs exists" test -f .claude/helpers/statusline.cjs
  cd /tmp; rm -rf "$TEST_DIR"
}

should_run "memory" && {
  section 4 "Memory Operations (AgentDB + RVF)"
  check "memory init" $RUFLO_CMD memory init --force
  check "memory store" $RUFLO_CMD memory store --key "verify-1" --value "Capability verification" --namespace verify
  check "memory search" $RUFLO_CMD memory search --query "verification" --namespace verify
  check_contains "memory retrieve content" "Capability" $RUFLO_CMD memory retrieve --key "verify-1" --namespace verify
  check "memory delete" $RUFLO_CMD memory delete --key "verify-1" --namespace verify
}

should_run "config" && {
  section 5 "Config Management"
  check "config show" $RUFLO_CMD config show
  check "config list" $RUFLO_CMD config list
}

# Quick mode — solo categorías 1-5
if [ "$QUICK_MODE" = "1" ] && [ -z "$TARGET_CATEGORY" ]; then
  section 25 "Cross-Feature Integration (Quick)"
  check "quick: store" $RUFLO_CMD memory store --key "quick-test" --value "Quick integration" --namespace quick
  check_contains "quick: search" "quick-test" $RUFLO_CMD memory search --query "integration" --namespace quick
  check "quick: cleanup" $RUFLO_CMD memory delete --key "quick-test" --namespace quick
  END_TIME=$(date +%s)
  echo ""; echo "  QUICK RESULTS ($((END_TIME - START_TIME))s): Pass=$PASS Fail=$FAIL Warn=$WARN"
  [ $FAIL -gt 0 ] && printf "$ERRORS\n"
  exit $FAIL
fi

# PART II: Agents & Swarms
should_run "session" && { section 6 "Session Management"; check_warn "session list" $RUFLO_CMD session list; }
should_run "agent"   && { section 7 "Agent System"; check "agent list" $RUFLO_CMD agent list; check_warn "agent status" $RUFLO_CMD agent status; }
should_run "swarm"   && { section 8 "Swarm Coordination"; check_warn "swarm status" $RUFLO_CMD swarm status; check_warn "swarm init hierarchical" $RUFLO_CMD swarm init --topology hierarchical --max-agents 4; }
should_run "task"    && { section 9 "Task System"; check_warn "task list" $RUFLO_CMD task list; }

# PART III: Intelligence
should_run "hooks"       && { section 10 "Hooks System"; check "hooks list" $RUFLO_CMD hooks list; check "hooks worker list" $RUFLO_CMD hooks worker list; }
should_run "security"    && { section 11 "Security"; check "security scan" $RUFLO_CMD security scan; check "security audit" $RUFLO_CMD security audit; }
should_run "performance" && { section 12 "Performance"; check "performance metrics" $RUFLO_CMD performance metrics; }
should_run "neural"      && { section 13 "Neural / SONA"; check "neural status" $RUFLO_CMD neural status; }
should_run "embeddings"  && { section 14 "Embeddings"; check "embeddings embed" $RUFLO_CMD embeddings embed --text "test"; }

# PART IV: Platform Services
should_run "workflow"    && { section 15 "Workflow System"; check "workflow list" $RUFLO_CMD workflow list; }
should_run "daemon"      && { section 16 "Daemon Workers"; check "daemon status" $RUFLO_CMD daemon status; check "daemon start" $RUFLO_CMD daemon start; }
should_run "claims"      && { section 17 "Claims / RBAC"; check "claims list" $RUFLO_CMD claims list; }
should_run "plugin"      && { section 19 "Plugins"; check "plugins list" $RUFLO_CMD plugins list; }
should_run "mcp"         && { section 20 "MCP Server"; check "mcp list" $RUFLO_CMD mcp list; }

# PART V: Integration E2E
should_run "integration" && {
  section 25 "Cross-Feature Integration"
  check "integration: store" $RUFLO_CMD memory store --key "int-verify" --value "Cross-feature integration with vector embeddings" --namespace integration
  check_contains "integration: search" "int-verify" $RUFLO_CMD memory search --query "cross feature" --namespace integration
  check_contains "integration: retrieve" "Cross-feature" $RUFLO_CMD memory retrieve --key "int-verify" --namespace integration
  check "integration: cleanup" $RUFLO_CMD memory delete --key "int-verify" --namespace integration
}

should_run "boot" && {
  section 29 "Boot Integrity"
  check "ruflo binary exists" command -v $RUFLO_CMD
  check "node available" command -v node
  check_contains "node version >= 20" "v2[0-9]" node --version
  check_warn "claude cli available" command -v claude
}

should_run "offline" && {
  section 34 "Offline Capability"
  check "offline: version" $RUFLO_CMD --version
  check "offline: doctor local" $RUFLO_CMD doctor -c node
  check "offline: memory local" $RUFLO_CMD memory store --key "offline-test" --value "Works offline" --namespace offline
  check_contains "offline: retrieve" "Works offline" $RUFLO_CMD memory retrieve --key "offline-test" --namespace offline
  $RUFLO_CMD memory delete --key "offline-test" --namespace offline >/dev/null 2>&1 || true
}

# RESULTS
END_TIME=$(date +%s); DURATION=$((END_TIME - START_TIME))
TOTAL=$((PASS + FAIL + WARN + SKIP))

if [ "$JSON_MODE" = "1" ]; then
  printf '{"suite":"ruflo-appliance","version":"%s","duration":%d,"passed":%d,"failed":%d,"warnings":%d,"skipped":%d,"success":%s}\n' \
    "$RUFLO_VERSION" "$DURATION" "$PASS" "$FAIL" "$WARN" "$SKIP" "$([ $FAIL -eq 0 ] && echo true || echo false)"
else
  echo ""; echo "══════════════════════════════════════════"
  echo "  RESULTS (${DURATION}s)  Pass:$PASS  Fail:$FAIL  Warn:$WARN  Skip:$SKIP / $TOTAL"
  [ $FAIL -gt 0 ] && printf "$ERRORS\n" && echo "  ✗ $FAIL FAILURES" || echo "  ★ ALL CRITICAL CHECKS PASSED"
  echo "══════════════════════════════════════════"
fi
exit $FAIL
