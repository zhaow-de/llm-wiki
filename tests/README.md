# llm-wiki Tests

Three-layer test suite for the llm-wiki Claude Code plugin.

## Layer 1: Structural Validation ($0, every push)

No LLM calls. Validates wiki file structure, frontmatter schema, index integrity, cross-references, and file placement against a golden wiki fixture.

```bash
# Generate defect fixtures (run once, or after changing golden-wiki)
./tests/generate-defect-fixtures.sh

# Run structural tests
./tests/test-structure.sh
./tests/test-local-cli-doctor.sh

# Validate plugin manifest
./tests/test-plugin-validate.sh
```

### What it checks

- C1: Every existing wiki-managed directory has `_index.md`
- C2: Required frontmatter fields present, enum values valid — for raw
  sources, wiki articles, thesis files, inventory records (C16), and dataset
  manifests (C17)
- C3: Index entries match actual files (no stale entries, no unlisted files)
- C4: All body links resolve (See Also, Sources, and inline prose links, in
  wiki articles and inventory records)
- C4b: Source references point to existing raw files, no retracted markers
- C5: No near-duplicate tags (via defect fixture)
- C6: No orphan sources (via defect fixture)
- C11: File placement matches frontmatter type/category/kind/dataset_id
- C12: No unknown file types in raw/wiki directories
- C14/C15/C18: stale article, missing volatility, missing sources (via defect
  fixtures)
- log.md entry format

`test-local-cli-doctor.sh` additionally runs every defect fixture through
`pkb.py doctor` end-to-end and covers the CLI's `--fix` repairs
(idempotency included), composite freshness scoring, hub resolution, and the
archive lifecycle with its error paths.

### Defect fixtures

`generate-defect-fixtures.sh` creates broken wikis from the golden fixture, one per checkup rule. Each has exactly one defect. The structural test verifies each defect is correctly present (negative testing).

## Layer 2: Behavioral Evals (~$2-5/run, on PR merge)

Uses Promptfoo with the Claude Agent SDK to test plugin behavior.

```bash
# Run evals
npx promptfoo@latest eval -c tests/promptfooconfig.yaml

# Run with variance measurement
npx promptfoo@latest eval -c tests/promptfooconfig.yaml --repeat 3
```

### What it tests

- Fuzzy router dispatches research/URL/question intents correctly — plus
  collection-import, collect-vs-inventory, dataset, topic-archive, refresh,
  librarian, and `--plan` routing
- Audit/trust prompts dispatch to the audit workflow
- Negative control: ambiguous input triggers clarification
- Onboarding: first-run behavior with no wiki present
- Plugin loads without errors

### Custom assertions

Three file-system assertion helpers live in `evals/assertions/` for tests that
need to verify what an eval run wrote to disk. They are not yet wired into
`promptfooconfig.yaml` (its current tests assert on routing behavior, not
file output):

- `evals/assertions/check-raw-source.js` — verifies raw source files have correct frontmatter
- `evals/assertions/check-index-integrity.js` — verifies all directories have `_index.md`
- `evals/assertions/check-frontmatter.js` — validates frontmatter schema with enum checks

## Fixtures

- `fixtures/golden-wiki/` — minimal but complete wiki: 4 sources, 2 articles,
  1 thesis, inventory and dataset layers, correct indexes and cross-references
- `fixtures/defects/` — generated broken wikis (one per checkup rule)
