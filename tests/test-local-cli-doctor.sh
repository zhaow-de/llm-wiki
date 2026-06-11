#!/bin/bash
# Validate the local deterministic pkb checkup (doctor) helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/pkb.py"
GOLDEN="$SCRIPT_DIR/fixtures/golden-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

expect_success() {
  local name="$1"
  shift
  local output
  if output="$("$@" 2>&1)" && grep -q "Result: PASS" <<<"$output"; then
    log_pass "$name"
  else
    log_fail "$name" "$output"
  fi
}

expect_failure_contains() {
  local name="$1"
  local expected="$2"
  shift 2
  local output
  set +e
  output="$("$@" 2>&1)"
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ] && grep -q "$expected" <<<"$output"; then
    log_pass "$name"
  else
    log_fail "$name" "$output"
  fi
}

# The composite freshness score (C14) decays with real time, so the golden
# fixture's static dates would eventually drop below the threshold and flip
# every PASS expectation. Tests that expect PASS lint a copy whose frontmatter
# dates are refreshed to today; FAIL expectations stay on the static fixtures.
TODAY="$(date +%Y-%m-%d)"

refresh_dates() {
  local dir="$1"
  find "$dir" -name '*.md' -type f -print0 | while IFS= read -r -d '' file; do
    sed -E -i.llmbak \
      "s/^(created|updated|verified|ingested):[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}/\1: $TODAY/" \
      "$file"
    rm -f "$file.llmbak"
  done
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
GOLDEN_FRESH="$tmpdir/golden-fresh"
mkdir "$GOLDEN_FRESH"
cp -R "$GOLDEN/." "$GOLDEN_FRESH/"
refresh_dates "$GOLDEN_FRESH"

echo "=== Local pkb CLI Doctor ==="

if [ -x "$CLI" ]; then
  log_pass "pkb.py is executable"
else
  log_fail "pkb.py is executable" "missing executable bit"
fi

expect_success "golden wiki passes local lint" "$CLI" doctor "$GOLDEN_FRESH"

expect_failure_contains \
  "missing-index fixture fails local lint" \
  "Required _index.md is missing" \
  "$CLI" doctor "$SCRIPT_DIR/fixtures/defects/missing-index"

expect_failure_contains \
  "bad-frontmatter fixture fails local lint" \
  "Invalid type" \
  "$CLI" doctor "$SCRIPT_DIR/fixtures/defects/bad-frontmatter"

mkdir "$tmpdir/wiki"
cp -R "$GOLDEN_FRESH/." "$tmpdir/wiki/"
mv "$tmpdir/wiki/wiki/concepts/sample-concept.md" \
  "$tmpdir/wiki/wiki/references/sample-concept.md"

expect_failure_contains \
  "misplaced file is reported" \
  "File is in the wrong directory" \
  "$CLI" doctor "$tmpdir/wiki"

set +e
fix_output="$("$CLI" doctor --fix "$tmpdir/wiki" 2>&1)"
fix_rc=$?
set -e
if [ "$fix_rc" -eq 0 ] \
  && grep -q "Moved wiki/references/sample-concept.md to wiki/concepts/sample-concept.md" <<<"$fix_output" \
  && [ -f "$tmpdir/wiki/wiki/concepts/sample-concept.md" ]; then
  log_pass "--fix moves misplaced wiki files"
else
  log_fail "--fix moves misplaced wiki files" "$fix_output"
fi

mkdir "$tmpdir/no-optional"
cp -R "$GOLDEN_FRESH/." "$tmpdir/no-optional/"
rm -rf "$tmpdir/no-optional/inventory" "$tmpdir/no-optional/datasets"
set +e
optional_output="$("$CLI" doctor --fix "$tmpdir/no-optional" 2>&1)"
optional_rc=$?
set -e
if [ "$optional_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$optional_output" \
  && [ ! -e "$tmpdir/no-optional/inventory" ] \
  && [ ! -e "$tmpdir/no-optional/datasets" ]; then
  log_pass "--fix preserves absent optional inventory and dataset layers"
else
  log_fail "--fix preserves absent optional inventory and dataset layers" "$optional_output"
fi

# inbox/ is an on-demand drop-zone (created by ingest / C12 quarantine), not a
# required directory. A wiki without inbox/ must lint clean, and --fix must not
# conjure one. Guards against re-adding a "missing inbox/" structural check.
inbox_absent="$tmpdir/inbox-absent"
mkdir "$inbox_absent"
cp -R "$GOLDEN_FRESH/." "$inbox_absent/"
rm -rf "$inbox_absent/inbox"
set +e
inbox_output="$("$CLI" doctor --fix "$inbox_absent" 2>&1)"
inbox_rc=$?
set -e
if [ "$inbox_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$inbox_output" \
  && [ ! -e "$inbox_absent/inbox" ]; then
  log_pass "lint neither requires nor creates a missing inbox/"
else
  log_fail "lint neither requires nor creates a missing inbox/" "$inbox_output"
fi

mkdir "$tmpdir/sparse-optional"
cp -R "$GOLDEN_FRESH/." "$tmpdir/sparse-optional/"
rm -rf "$tmpdir/sparse-optional/inventory" "$tmpdir/sparse-optional/datasets"
mkdir -p "$tmpdir/sparse-optional/inventory" "$tmpdir/sparse-optional/datasets/sparse-dataset"
cat > "$tmpdir/sparse-optional/inventory/_index.md" <<'EOF'
# Inventory Index

## Contents
EOF
cat > "$tmpdir/sparse-optional/datasets/_index.md" <<'EOF'
# Dataset Registry Index

## Contents

| Dataset | Status | Storage | Formats | Size | Records | Updated |
|---------|--------|---------|---------|------|---------|---------|
| [Sparse Dataset](sparse-dataset/MANIFEST.md) | external | external | csv | unknown | unknown | 2026-01-03 |
EOF
cat > "$tmpdir/sparse-optional/datasets/sparse-dataset/_index.md" <<'EOF'
# Sparse Dataset Index

## Contents

| File | Summary | Tags | Updated |
|------|---------|------|---------|
| [MANIFEST.md](MANIFEST.md) | Sparse optional-layer fixture. | sparse | 2026-01-03 |
EOF
cat > "$tmpdir/sparse-optional/datasets/sparse-dataset/MANIFEST.md" <<'EOF'
---
title: "Sparse Dataset"
dataset_id: sparse-dataset
status: external
storage: external
locations:
  - https://example.com/sparse.csv
formats: [csv]
schema_status: unknown
created: 2026-01-03
updated: 2026-01-03
tags: [sparse]
summary: "Sparse optional-layer fixture."
---

# Sparse Dataset
EOF
set +e
sparse_output="$("$CLI" doctor --fix "$tmpdir/sparse-optional" 2>&1)"
sparse_rc=$?
set -e
if [ "$sparse_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$sparse_output" \
  && [ ! -e "$tmpdir/sparse-optional/inventory/items" ] \
  && [ ! -e "$tmpdir/sparse-optional/datasets/sparse-dataset/samples" ] \
  && [ ! -e "$tmpdir/sparse-optional/datasets/sparse-dataset/profiles" ] \
  && [ ! -e "$tmpdir/sparse-optional/datasets/sparse-dataset/queries" ]; then
  log_pass "--fix preserves sparse optional layer subdirectories"
else
  log_fail "--fix preserves sparse optional layer subdirectories" "$sparse_output"
fi

librarian_noise="$tmpdir/librarian-noise"
mkdir "$librarian_noise"
cp -R "$GOLDEN_FRESH/." "$librarian_noise/"
mkdir -p "$librarian_noise/.librarian/backup/raw/articles"
cat > "$librarian_noise/.librarian/backup/raw/articles/_index.md" <<'EOF'
# Backup Articles

[dead.md](dead.md)
EOF

expect_success \
  "lint ignores maintenance backup indexes under .librarian" \
  "$CLI" doctor "$librarian_noise"

# .obsidian/ at wiki root must be tolerated (allowed at both root and hub level).
obsidian_wiki="$tmpdir/obsidian-wiki"
mkdir "$obsidian_wiki"
cp -R "$GOLDEN_FRESH/." "$obsidian_wiki/"
mkdir "$obsidian_wiki/.obsidian"
set +e
obsidian_output="$("$CLI" doctor "$obsidian_wiki" 2>&1)"
obsidian_rc=$?
set -e
if [ "$obsidian_rc" -eq 0 ] \
  && ! grep -qi "unknown" <<<"$obsidian_output"; then
  log_pass ".obsidian/ at wiki root is tolerated without unknown warning"
else
  log_fail ".obsidian/ at wiki root is tolerated without unknown warning" "$obsidian_output"
fi

legacy_repair="$tmpdir/legacy-repair"
mkdir "$legacy_repair"
cp -R "$GOLDEN_FRESH/." "$legacy_repair/"
cat > "$legacy_repair/raw/articles/2026-01-04-quantum-canary-satoshi-coins.md" <<'EOF'
---
title: "Quantum Canary Satoshi Coins"
source: https://example.com/quantum-canary
type: articles
ingested: 2026-01-04
tags: [quantum, bitcoin]
summary: "Quantum Canary source fixture for fuzzy source repair."
---

# Quantum Canary Satoshi Coins
EOF
cat > "$legacy_repair/wiki/topics/legacy-topic.md" <<'EOF'
---
title: "Legacy Topic"
tags: [legacy, quantum]
confidence: high
sources: [quantum-canary]
created: 2026-01-04
updated: 2026-01-04
---

# Legacy Topic

This older compiled article has useful prose but lacks newer schema fields that lint can safely infer from its directory and first paragraph.
EOF
cat >> "$legacy_repair/wiki/topics/_index.md" <<'EOF'
| [Dead Topic](dead-topic.md) | no longer present | low | 2025-01-01 |
EOF
set +e
legacy_output="$("$CLI" doctor --fix "$legacy_repair" 2>&1)"
legacy_rc=$?
set -e
if [ "$legacy_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$legacy_output" \
  && grep -q "category: topic" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "summary:" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "volatility: warm" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "raw/articles/2026-01-04-quantum-canary-satoshi-coins.md" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "Legacy Topic" "$legacy_repair/wiki/topics/_index.md" \
  && ! grep -q "dead-topic.md" "$legacy_repair/wiki/topics/_index.md"; then
  log_pass "--fix repairs legacy frontmatter, source refs, and indexes"
else
  log_fail "--fix repairs legacy frontmatter, source refs, and indexes" "$legacy_output"
fi

coverage_repair="$tmpdir/coverage-repair"
mkdir "$coverage_repair"
cp -R "$GOLDEN_FRESH/." "$coverage_repair/"
cat > "$coverage_repair/raw/articles/2026-01-05-uncompiled-source.md" <<'EOF'
---
title: "Uncompiled Source"
source: https://example.com/uncompiled
type: articles
ingested: 2026-01-05
tags: [coverage]
summary: "Uncompiled raw source fixture for coverage repair."
---

# Uncompiled Source
EOF
set +e
coverage_output="$("$CLI" doctor --fix "$coverage_repair" 2>&1)"
coverage_rc=$?
set -e
if [ "$coverage_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$coverage_output" \
  && [ -f "$coverage_repair/wiki/references/uncompiled-source-coverage.md" ] \
  && grep -q "raw/articles/2026-01-05-uncompiled-source.md" "$coverage_repair/wiki/references/uncompiled-source-coverage.md" \
  && grep -q "Uncompiled Source Coverage" "$coverage_repair/wiki/references/_index.md"; then
  log_pass "--fix creates explicit coverage reference for uncompiled raw sources"
else
  log_fail "--fix creates explicit coverage reference for uncompiled raw sources" "$coverage_output"
fi

hub_scope="$tmpdir/hub-scope"
mkdir -p "$hub_scope/topics/noisy-topic"
cp -R "$SCRIPT_DIR/fixtures/defects/missing-index/." "$hub_scope/topics/noisy-topic/"
cat > "$hub_scope/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$hub_scope/log.md" <<'EOF'
# Hub Log
EOF
cat > "$hub_scope/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "noisy-topic": { "path": "topics/noisy-topic", "description": "Noisy topic" }
  },
  "local_wikis": []
}
JSON

expect_success \
  "hub lint stays scoped to hub registry" \
  "$CLI" doctor "$hub_scope"

portable_home="$tmpdir/portable-home"
portable_hub="$portable_home/Library/Mobile Documents/com~apple~CloudDocs/wiki"
mkdir -p "$portable_home/.config/llm-wiki" "$portable_hub/topics/portable-topic"
cp -R "$GOLDEN_FRESH/." "$portable_hub/topics/portable-topic/"
cat > "$portable_home/.config/llm-wiki/config.json" <<'JSON'
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "/Users/olduser/Library/Mobile Documents/com~apple~CloudDocs/wiki"
}
JSON
cat > "$portable_hub/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$portable_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "portable-topic": {
      "path": "/Users/olduser/Library/Mobile Documents/com~apple~CloudDocs/wiki/topics/portable-topic",
      "description": "Portable topic"
    }
  },
  "local_wikis": []
}
JSON

expect_success \
  "portable hub_path beats stale resolved_path and registry path" \
  env HOME="$portable_home" "$CLI" doctor --wiki portable-topic

lag_home="$tmpdir/lag-home"
lag_hub="$lag_home/Library/Mobile Documents/com~apple~CloudDocs/wiki"
stale_resolved_hub="$tmpdir/stale-resolved-hub"
mkdir -p "$lag_home/.config/llm-wiki" "$lag_hub/topics/lag-topic" "$stale_resolved_hub"
cp -R "$GOLDEN_FRESH/." "$lag_hub/topics/lag-topic/"
cat > "$lag_home/.config/llm-wiki/config.json" <<JSON
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "$stale_resolved_hub"
}
JSON
cat > "$lag_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "lag-topic": { "path": "topics/lag-topic", "description": "Lag topic" }
  },
  "local_wikis": []
}
JSON
cat > "$stale_resolved_hub/_index.md" <<'EOF'
# Stale Hub Index
EOF

expect_success \
  "existing hub_path wins even when hub _index is not present yet" \
  env HOME="$lag_home" "$CLI" doctor --wiki lag-topic

relative_hub="$tmpdir/relative-hub"
mkdir -p "$relative_hub/topics/relative-topic"
cp -R "$GOLDEN_FRESH/." "$relative_hub/topics/relative-topic/"
cat > "$relative_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "relative-topic": { "path": "topics/relative-topic", "description": "Relative topic" }
  },
  "local_wikis": []
}
JSON

expect_success \
  "relative wikis.json paths resolve from hub" \
  "$CLI" doctor --hub "$relative_hub" --wiki relative-topic

archive_hub="$tmpdir/archive-hub"
mkdir -p "$archive_hub/topics/archive-topic"
cp -R "$GOLDEN_FRESH/." "$archive_hub/topics/archive-topic/"
cat > "$archive_hub/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$archive_hub/log.md" <<'EOF'
# Hub Log
EOF
cat > "$archive_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "archive-topic": { "path": "topics/archive-topic", "description": "Archive topic" }
  },
  "local_wikis": []
}
JSON

set +e
archive_output="$("$CLI" archive --hub "$archive_hub" topic archive-topic --reason "No longer active" 2>&1)"
archive_rc=$?
set -e
if [ "$archive_rc" -eq 0 ] \
  && [ -d "$archive_hub/topics/.archive/archive-topic" ] \
  && [ ! -e "$archive_hub/topics/archive-topic" ] \
  && grep -q '"status": "archived"' "$archive_hub/wikis.json" \
  && grep -q 'topics/.archive/archive-topic' "$archive_hub/wikis.json"; then
  log_pass "archive command moves topic and marks registry archived"
else
  log_fail "archive command moves topic and marks registry archived" "$archive_output"
fi

expect_failure_contains \
  "archived wiki is rejected by default resolution" \
  "wiki is archived" \
  "$CLI" doctor --hub "$archive_hub" --wiki archive-topic

expect_success \
  "archived wiki can be linted explicitly" \
  "$CLI" doctor --hub "$archive_hub" --wiki archive-topic --include-archived

set +e
restore_output="$("$CLI" archive --hub "$archive_hub" restore archive-topic 2>&1)"
restore_rc=$?
set -e
if [ "$restore_rc" -eq 0 ] \
  && [ -d "$archive_hub/topics/archive-topic" ] \
  && [ ! -e "$archive_hub/topics/.archive/archive-topic" ] \
  && grep -q '"status": "active"' "$archive_hub/wikis.json" \
  && grep -q 'topics/archive-topic' "$archive_hub/wikis.json"; then
  log_pass "archive restore moves topic back and marks registry active"
else
  log_fail "archive restore moves topic back and marks registry active" "$restore_output"
fi

bad_registry_hub="$tmpdir/bad-registry-hub"
mkdir -p "$bad_registry_hub/topics/bad-registry-topic"
cp -R "$GOLDEN_FRESH/." "$bad_registry_hub/topics/bad-registry-topic/"
printf '' > "$bad_registry_hub/wikis.json"

expect_success \
  "topic directory fallback works when wikis.json is unreadable" \
  "$CLI" doctor --hub "$bad_registry_hub" --wiki bad-registry-topic

permission_hub="$tmpdir/permission-hub"
mkdir -p "$permission_hub/topics/denied-topic"
cp -R "$GOLDEN_FRESH/." "$permission_hub/topics/denied-topic/"
cat > "$permission_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "denied-topic": { "path": "topics/denied-topic", "description": "Denied topic" }
  },
  "local_wikis": []
}
JSON
chmod 000 "$permission_hub/wikis.json"
expect_failure_contains \
  "permission-denied registry read gives actionable diagnostic" \
  "Full Disk Access" \
  "$CLI" doctor --hub "$permission_hub" --wiki denied-topic
chmod 644 "$permission_hub/wikis.json"

# Every generated defect fixture must be detected end-to-end by the lint engine
# (test-structure.sh only asserts the defect is present in the fixture).
# missing-volatility is the one info-severity defect: it must still PASS while
# reporting the missing field.
for defect_dir in "$SCRIPT_DIR"/fixtures/defects/*/; do
  defect="$(basename "$defect_dir")"
  if [ "$defect" = "missing-volatility" ]; then
    # PASS expectation, so lint a date-refreshed copy (see refresh_dates above).
    mv_fresh="$tmpdir/missing-volatility-fresh"
    rm -rf "$mv_fresh"
    mkdir "$mv_fresh"
    cp -R "$defect_dir." "$mv_fresh/"
    refresh_dates "$mv_fresh"
    set +e
    sweep_output="$("$CLI" doctor "$mv_fresh" 2>&1)"
    sweep_rc=$?
    set -e
    if [ "$sweep_rc" -eq 0 ] \
      && grep -q "Result: PASS" <<<"$sweep_output" \
      && grep -q "Compiled article has no volatility field" <<<"$sweep_output"; then
      log_pass "defect fixture $defect lints PASS with info finding"
    else
      log_fail "defect fixture $defect lints PASS with info finding" "$sweep_output"
    fi
  else
    expect_failure_contains \
      "defect fixture $defect fails local lint" \
      "Result: FAIL" \
      "$CLI" doctor "$defect_dir"
  fi
done

# A second --fix run on an already-repaired wiki must change nothing: the
# writers (index regeneration, coverage reference, legacy frontmatter) must
# produce output the checkers accept as-is.
for repaired in legacy-repair coverage-repair; do
  set +e
  rerun_output="$("$CLI" doctor --fix "$tmpdir/$repaired" 2>&1)"
  rerun_rc=$?
  set -e
  if [ "$rerun_rc" -eq 0 ] \
    && grep -q "Result: PASS" <<<"$rerun_output" \
    && grep -q "0 auto-fixed" <<<"$rerun_output"; then
    log_pass "--fix is idempotent on repaired $repaired"
  else
    log_fail "--fix is idempotent on repaired $repaired" "$rerun_output"
  fi
done

# --fix must not green-light what it cannot repair: config.md is not fixable,
# so the run still fails and the file is not conjured.
unfixable="$tmpdir/unfixable"
mkdir "$unfixable"
cp -R "$GOLDEN_FRESH/." "$unfixable/"
rm "$unfixable/config.md"
expect_failure_contains \
  "--fix still fails on unfixable missing config.md" \
  "config.md is missing" \
  "$CLI" doctor --fix "$unfixable"
if [ ! -e "$unfixable/config.md" ]; then
  log_pass "--fix does not conjure a missing config.md"
else
  log_fail "--fix does not conjure a missing config.md" "config.md was created"
fi

# A file with unterminated frontmatter is reported exactly once, even though
# lint reloads documents after the fix passes.
unterminated="$tmpdir/unterminated"
mkdir "$unterminated"
cp -R "$GOLDEN_FRESH/." "$unterminated/"
printf -- '---\ntitle: "Broken Frontmatter"\n' \
  > "$unterminated/raw/articles/2026-01-06-broken-frontmatter.md"
set +e
unterminated_output="$("$CLI" doctor "$unterminated" 2>&1)"
unterminated_rc=$?
set -e
unterminated_count="$(grep -c "unterminated YAML frontmatter" <<<"$unterminated_output" || true)"
if [ "$unterminated_rc" -ne 0 ] && [ "$unterminated_count" -eq 1 ]; then
  log_pass "unterminated frontmatter is reported exactly once"
else
  log_fail "unterminated frontmatter is reported exactly once" "$unterminated_output"
fi

# C14 composite freshness: the stale-article defect (hot, verified 2025-01-01)
# must report the spec'd score breakdown, not a day-cutoff heuristic.
expect_failure_contains \
  "stale article reports composite freshness score" \
  "Freshness score " \
  "$CLI" doctor "$SCRIPT_DIR/fixtures/defects/stale-article"

# freshness_threshold from config.md frontmatter is honored: warm articles
# verified long ago score ~51 (fresh sources keep two dimensions at 25), which
# fails the default threshold of 70 but passes an explicit threshold of 40.
threshold_wiki="$tmpdir/threshold-wiki"
mkdir "$threshold_wiki"
cp -R "$GOLDEN_FRESH/." "$threshold_wiki/"
for article in wiki/concepts/sample-concept.md wiki/references/sample-reference.md; do
  sed -E -i.llmbak \
    's/^(verified|updated):.*/\1: 2025-01-01/' \
    "$threshold_wiki/$article"
  rm -f "$threshold_wiki/$article.llmbak"
done
expect_failure_contains \
  "long-unverified warm articles fail the default freshness threshold" \
  "Freshness score " \
  "$CLI" doctor "$threshold_wiki"
cat > "$threshold_wiki/config.md" <<EOF
---
title: "Test Wiki"
description: "A minimal wiki fixture for structural validation testing"
created: $TODAY
freshness_threshold: 40
---

# Wiki Configuration
EOF
expect_success \
  "config freshness_threshold overrides the default" \
  "$CLI" doctor "$threshold_wiki"

# Cold articles below threshold are info severity (Lindy Effect), not warnings:
# the lint result stays PASS while the score is still reported.
cold_wiki="$tmpdir/cold-wiki"
mkdir "$cold_wiki"
cp -R "$GOLDEN_FRESH/." "$cold_wiki/"
sed -E -i.llmbak \
  -e 's/^volatility:.*/volatility: cold/' \
  -e 's/^(verified|updated):.*/\1: 2025-01-01/' \
  "$cold_wiki/wiki/concepts/sample-concept.md"
rm -f "$cold_wiki/wiki/concepts/sample-concept.md.llmbak"
set +e
cold_output="$("$CLI" doctor "$cold_wiki" 2>&1)"
cold_rc=$?
set -e
if [ "$cold_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$cold_output" \
  && grep -q "Freshness score " <<<"$cold_output"; then
  log_pass "cold article below threshold is info severity"
else
  log_fail "cold article below threshold is info severity" "$cold_output"
fi

# compiled-from: conversation articles use the rebased two-dimension score and
# the conversation-specific message, and stay exempt from the sources warning.
conversation_wiki="$tmpdir/conversation-wiki"
mkdir "$conversation_wiki"
cp -R "$GOLDEN_FRESH/." "$conversation_wiki/"
cat > "$conversation_wiki/wiki/concepts/conversation-note.md" <<'EOF'
---
title: "Conversation Note"
category: concept
compiled-from: conversation
created: 2025-01-01
updated: 2025-01-01
tags: [conversation]
confidence: low
volatility: hot
verified: 2025-01-01
summary: "Conversation-sourced article fixture for freshness scoring."
---

# Conversation Note
EOF
set +e
conversation_output="$("$CLI" doctor "$conversation_wiki" 2>&1)"
conversation_rc=$?
set -e
if [ "$conversation_rc" -ne 0 ] \
  && grep -q "conversation-sourced" <<<"$conversation_output" \
  && ! grep -q "missing sources" <<<"$conversation_output"; then
  log_pass "conversation-sourced article uses rebased freshness message"
else
  log_fail "conversation-sourced article uses rebased freshness message" "$conversation_output"
fi

# A dead link in a hand-shaped bucket index (wiki/_index.md) must be removed
# surgically: --fix may not regenerate the navigation index into a flat table.
bucket_wiki="$tmpdir/bucket-index"
mkdir "$bucket_wiki"
cp -R "$GOLDEN_FRESH/." "$bucket_wiki/"
printf '\n## Stale\nSee [gone/_index.md](gone/_index.md)\n' >> "$bucket_wiki/wiki/_index.md"
set +e
bucket_output="$("$CLI" doctor --fix "$bucket_wiki" 2>&1)"
bucket_rc=$?
set -e
if [ "$bucket_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$bucket_output" \
  && grep -q "Removed 1 dead link line" <<<"$bucket_output" \
  && grep -q "concepts/_index.md" "$bucket_wiki/wiki/_index.md" \
  && grep -q "theses/_index.md" "$bucket_wiki/wiki/_index.md" \
  && ! grep -q "gone/_index.md" "$bucket_wiki/wiki/_index.md"; then
  log_pass "--fix removes dead bucket-index lines without regenerating"
else
  log_fail "--fix removes dead bucket-index lines without regenerating" "$bucket_output"
fi

# A dataset slug index (datasets/<slug>/_index.md) is also hand-shaped (manifest
# row + Quick Navigation to samples/profiles/queries); a dead link there must be
# removed surgically, not regenerated into a flat MANIFEST-only table.
dataset_index="$tmpdir/dataset-index"
mkdir "$dataset_index"
cp -R "$GOLDEN_FRESH/." "$dataset_index/"
ds_index="$dataset_index/datasets/bitcointalk-temporal-graph/_index.md"
printf '\n## Stale\nSee [gone/_index.md](gone/_index.md)\n' >> "$ds_index"
set +e
dataset_output="$("$CLI" doctor --fix "$dataset_index" 2>&1)"
dataset_rc=$?
set -e
if [ "$dataset_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$dataset_output" \
  && grep -q "Removed 1 dead link line" <<<"$dataset_output" \
  && grep -q "Quick Navigation" "$ds_index" \
  && grep -q "samples/_index.md" "$ds_index" \
  && ! grep -q "gone/_index.md" "$ds_index"; then
  log_pass "--fix removes dead dataset-index lines without regenerating"
else
  log_fail "--fix removes dead dataset-index lines without regenerating" "$dataset_output"
fi

# An empty scalar field must be repaired in place: the old parser let an empty
# updated: swallow the next line as its value, leaving the field broken and
# writing garbage dates inferred from it.
empty_field="$tmpdir/empty-field"
mkdir "$empty_field"
cp -R "$GOLDEN_FRESH/." "$empty_field/"
cat > "$empty_field/wiki/topics/empty-updated.md" <<EOF
---
title: "Empty Updated"
category: topic
sources:
  - raw/articles/2026-01-01-sample-article.md
created: $TODAY
updated:
verified: $TODAY
tags: [legacy]
confidence: medium
volatility: warm
summary: "Article with an empty updated field for repair testing."
---

# Empty Updated

This fixture exercises repair of empty scalar frontmatter fields.
EOF
set +e
empty_output="$("$CLI" doctor --fix "$empty_field" 2>&1)"
empty_rc=$?
set -e
empty_updated_count="$(grep -c '^updated:' "$empty_field/wiki/topics/empty-updated.md" || true)"
if [ "$empty_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$empty_output" \
  && [ "$empty_updated_count" -eq 1 ] \
  && grep -q "^updated: $TODAY" "$empty_field/wiki/topics/empty-updated.md" \
  && ! grep -q "created: verified:" "$empty_field/wiki/topics/empty-updated.md"; then
  log_pass "--fix repairs an empty updated field in place"
else
  log_fail "--fix repairs an empty updated field in place" "$empty_output"
fi

# Archive error paths: every guard before the destructive move must reject
# cleanly, and the registry/filesystem must be left untouched.
expect_failure_contains \
  "archive rejects nonexistent topic" \
  "active topic not found" \
  "$CLI" archive --hub "$archive_hub" topic ghost-topic

expect_failure_contains \
  "archive rejects the synthetic hub entry" \
  "cannot archive the synthetic hub entry" \
  "$CLI" archive --hub "$archive_hub" topic hub

expect_failure_contains \
  "restore rejects an active topic" \
  "active topic destination already exists" \
  "$CLI" archive --hub "$archive_hub" restore archive-topic

expect_failure_contains \
  "restore rejects a nonexistent topic" \
  "archived topic not found" \
  "$CLI" archive --hub "$archive_hub" restore ghost-topic

set +e
"$CLI" archive --hub "$archive_hub" topic archive-topic --reason "again" >/dev/null 2>&1
set -e
expect_failure_contains \
  "archive rejects an already-archived topic" \
  "topic already archived" \
  "$CLI" archive --hub "$archive_hub" topic archive-topic

collision_hub="$tmpdir/collision-hub"
mkdir -p "$collision_hub/topics/collision-topic" "$collision_hub/topics/.archive/collision-topic"
cp -R "$GOLDEN_FRESH/." "$collision_hub/topics/collision-topic/"
cat > "$collision_hub/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$collision_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" }
  },
  "local_wikis": []
}
JSON
expect_failure_contains \
  "archive rejects an existing archive destination" \
  "archive destination already exists" \
  "$CLI" archive --hub "$collision_hub" topic collision-topic

no_registry_hub="$tmpdir/no-registry-hub"
mkdir -p "$no_registry_hub/topics"
expect_failure_contains \
  "archive requires an initialized hub" \
  "initialized hub not found" \
  "$CLI" archive --hub "$no_registry_hub" list

malformed_hub="$tmpdir/malformed-hub"
mkdir -p "$malformed_hub/topics"
printf 'not json' > "$malformed_hub/wikis.json"
expect_failure_contains \
  "archive rejects a malformed registry" \
  "invalid wiki registry" \
  "$CLI" archive --hub "$malformed_hub" list

# Path-traversal slugs must be rejected before any move: a slug with
# separators or leading dots could drag directories from outside the hub.
escapee="$tmpdir/escapee"
mkdir "$escapee"
cp -R "$GOLDEN_FRESH/." "$escapee/"
expect_failure_contains \
  "archive rejects path-traversal slug" \
  "invalid topic slug" \
  "$CLI" archive --hub "$archive_hub" topic "../../escapee"
expect_failure_contains \
  "restore rejects path-traversal slug" \
  "invalid topic slug" \
  "$CLI" archive --hub "$archive_hub" restore "../escapee"
if [ -d "$escapee" ] && ! grep -q 'escapee' "$archive_hub/wikis.json"; then
  log_pass "traversal slug leaves filesystem and registry untouched"
else
  log_fail "traversal slug leaves filesystem and registry untouched" "$(cat "$archive_hub/wikis.json")"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
