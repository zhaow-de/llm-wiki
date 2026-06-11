#!/bin/bash
# Validate plugin manifest and command/skill frontmatter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$PROJECT_ROOT/plugin"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
PASS=0
FAIL=0
TOTAL=0
REFERENCE_NAMES="archive audit command-prelude compilation datasets hub-resolution indexing ingestion inventory librarian doctor projects research-infrastructure wiki-structure"

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s — %s\n" "$1" "$2"; }

echo "=== Plugin Validation ==="

# plugin.json
if [ -f "$PLUGIN_JSON" ]; then
  log_pass "plugin.json exists"
  if python3 -c "import json; json.load(open('$PLUGIN_JSON'))" 2>/dev/null; then
    log_pass "plugin.json is valid JSON"
  else
    log_fail "plugin.json is invalid JSON" "parse error"
  fi
else
  log_fail "plugin.json not found at $PLUGIN_JSON" "missing file"
fi

# Every command .md has frontmatter (starts with ---)
echo ""
echo "--- Command frontmatter ---"
for cmd in "$PLUGIN_DIR"/commands/*.md; do
  basename=$(basename "$cmd")
  if head -1 "$cmd" | grep -q "^---$"; then
    log_pass "frontmatter in commands/$basename"
  else
    log_fail "no frontmatter in commands/$basename" "missing ---"
  fi
done

# SKILL.md exists
echo ""
echo "--- Skill files ---"
if [ -f "$PLUGIN_DIR/skills/pkb-manager/SKILL.md" ]; then
  log_pass "SKILL.md exists"
  if head -1 "$PLUGIN_DIR/skills/pkb-manager/SKILL.md" | grep -q "^---$"; then
    log_pass "SKILL.md has frontmatter"
  else
    log_fail "SKILL.md has no frontmatter" "missing ---"
  fi
else
  log_fail "SKILL.md not found" "missing file"
fi

# Reference files exist
echo ""
echo "--- Reference files ---"
for ref in $REFERENCE_NAMES; do
  reffile="$PLUGIN_DIR/skills/pkb-manager/references/${ref}.md"
  if [ -f "$reffile" ]; then
    log_pass "references/$ref.md exists"
  else
    log_fail "references/$ref.md missing" "missing file"
  fi
done

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
