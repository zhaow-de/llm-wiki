# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is **not an application** — it's a Claude Code plugin that ships *behavioral instructions* (a markdown skill + command specs) telling Claude how to build and manage a knowledge-base wiki. There is no compiled code and no server. The wiki data itself lives at runtime in `~/llm-wiki-data/` (or a configured hub path), never in this repo. The repo's "logic" is prose in markdown plus one dependency-free Python CLI for the deterministic, no-LLM checks.

Claude Code is the only supported runtime. The plugin is installed locally from this checkout via `.claude-plugin/marketplace.json` — there is no marketplace publishing and no other-runtime packaging.

## Two Roles — Don't Confuse Them

This repo is read in two distinct roles, and each has its own instruction source so neither pays for the other's context:

- **Developing the plugin** (testing, the release flow, repo structure, conventions): **this file, `CLAUDE.md`**, is the source of truth. Claude Code loads it automatically in this repo.
- **Using the plugin** to build and maintain wiki *content* (research, ingest, compile, query, …): the **`pkb-manager` skill** (`plugin/skills/pkb-manager/SKILL.md` + `references/*.md`) is the runtime protocol. A skill's body is lazy-loaded — only when wiki work activates — so it costs nothing while you develop the plugin.

When working on the plugin codebase, treat `CLAUDE.md` as authoritative for repo-level workflow; the skill files are the artifact you edit, not instructions for *this* session.

## Source of Truth

The single behavioral source of truth is **`plugin/`**:

- `plugin/skills/pkb-manager/SKILL.md` — skill manifest: hub resolution, core principles, structural guardian (the fuzzy router lives in `plugin/commands/pkb.md`).
- `plugin/skills/pkb-manager/references/*.md` — the operation specs (hub-resolution, ingestion, compilation, doctor, audit, …).
- `plugin/commands/*.md` — one spec per `/pkb` and `/pkb:*` command.

There are no generated mirrors. Editing a reference *is* editing runtime behavior.

## Rules

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly; mark each as *validated / assumed / unknown*.
- If multiple interpretations exist, present 2–3 with tradeoffs — don't pick silently.
- Distinguish *symptom* ("button is slow") from *problem* ("users abandon checkout").
- Name confidence on non-obvious choices: *high / medium / low*.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked. No "while I'm here."
- No abstractions for single-use code.
- No flexibility, configurability, or error handling that wasn't requested.
- If you write 200 lines and it could be 50, rewrite it.

Self-check: "Would a senior engineer call this overcomplicated?" Complexity is rarely a sign of intelligence — more often, it's a sign of confusion.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Remove imports / variables / functions that *your* changes made unused.
- Don't delete pre-existing dead code — mention it instead.

The test: every changed line traces directly to the user's request.

### 4. Define Done by Outcome, Not Output

**"Merged" is not "done." Done is "it works and we can tell."**

Transform vague tasks into verifiable goals:

| Weak               | Strong                                                                  |
| ------------------ | ----------------------------------------------------------------------- |
| "Add validation"   | "Invalid inputs rejected with clear messages; tests cover each case"    |
| "Fix the bug"      | "Failing test reproduces it; passes after fix; no regression elsewhere" |
| "Refactor X"       | "Tests pass identically before and after"                               |

For user-facing work, acceptance covers three layers:

- **Functional** — tests pass; edge cases handled
- **User-facing** — a real user flow completes end-to-end
- **Operational** — observable in production (logs, errors, analytics)

For multi-step work, state a brief plan:

```
1. [step] → verify: [check]
2. [step] → verify: [check]
3. [step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Local Deterministic CLI

`pkb.py` is a standalone, dependency-free Python implementation of the structural (no-LLM) parts of doctor and archive — used both by end users (`./pkb.py doctor /path/to/llm-wiki-data`, `--fix`, `archive ...`) and by the test suite (`tests/test-local-cli-doctor.sh`). The agentic `/pkb:doctor` workflow remains the full editorial protocol; this CLI only covers what can be checked deterministically.

## Tooling

- This repo is not a Python application. **uv** is engaged only to run **pre-commit** and pin the dev toolchain (`pyproject.toml` `[dependency-groups] dev`, `uv.lock`).
- Python is pinned by `.python-version`.
- Run dev tooling through uv so the locked environment is used.

## Commands

```bash
uv sync                              # install/refresh the locked dev environment
uv run pre-commit install            # one-time: activate the commit-time hook gate
uv run pre-commit run --all-files    # run the full pre-commit suite

./tests/test-plugin-validate.sh      # plugin manifest + command/skill frontmatter
./tests/test-structure.sh            # wiki fixture validation
./tests/test-local-cli-doctor.sh     # local pkb.py doctor helper

./pkb.py doctor /path/to/llm-wiki-data        # deterministic checkup
./pkb.py doctor --fix /path/to/llm-wiki-data  # + safe auto-fixes
```

Cut releases with the `/release` skill (commitizen-driven). See `.claude/rules/branch-workflow.md`.

## Testing

Run the structural tests before declaring any change to plugin code done — they need no LLM and are instant:

```bash
./tests/test-plugin-validate.sh   # plugin manifest + command/skill frontmatter
./tests/test-structure.sh          # wiki fixture validation
./tests/test-local-cli-doctor.sh   # local pkb.py doctor helper
```

Behavioral evals (run when changing command/routing logic; needs `ANTHROPIC_API_KEY`, costs ~$2–5 per run):

```bash
npx promptfoo@latest eval -c tests/promptfooconfig.yaml
```

If you changed the golden wiki fixture, regenerate the defect fixtures first:

```bash
./tests/generate-defect-fixtures.sh
```

### When to update tests

- **Added a new checkup rule**: add a defect fixture in `generate-defect-fixtures.sh` and a negative test case in `test-structure.sh`.
- **Changed frontmatter schema** (new required field, renamed enum): update the golden wiki fixture files to match, update `test-structure.sh` field/enum lists, regenerate defect fixtures.
- **Added a new command**: `test-plugin-validate.sh` checks command frontmatter via a wildcard; add a behavioral eval in `promptfooconfig.yaml` for routing.
- **Changed the fuzzy router**: add or update test cases in `promptfooconfig.yaml` covering the new routing behavior plus negative controls.
- **Added a new reference file**: add its filename to `REFERENCE_NAMES` in `test-plugin-validate.sh`.
- **Changed directory structure** (new `raw/` or `wiki/` subdirectory): update `test-structure.sh` C1 directory list and C11 placement checks, and the golden wiki fixture if needed.

### Test file locations

- `tests/fixtures/golden-wiki/` — known-correct wiki (sources, articles, all indexes)
- `tests/fixtures/defects/` — generated broken wikis (one per checkup rule)
- `tests/promptfooconfig.yaml` — Promptfoo behavioral eval config
- `tests/evals/assertions/*.js` — custom JS assertions for file-system checks

## Conventions

- **pre-commit** is the gate for commits: standard hygiene hooks, **yamllint**, and **mdformat** (which formats `README.md` + `docs/open-topics/README.md` and regenerates their tables of contents — don't hand-maintain them). Hooks may rewrite files and abort the commit; re-stage and re-commit (never `--no-verify`).
- **Versioning** is commitizen-managed (`.cz.toml`). `cz bump` (run by the `/release` skill) is the source of truth for the version and updates `pyproject.toml`, the README `Version` badge, `plugin/.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json` together — don't hand-edit them or they'll drift.
- **Workflow conventions** live in `.claude/rules/`: branch model (`branch-workflow.md`), PR title/body + co-author/reviewer trailers (`pull-requests.md`), commit messages (`commit-messages.md`), README command docs (`readme-usage.md`), spec & plan locations (`spec-plan-locations.md`), the iterations-history entry every plan must end with (`iterations-history.md`), the open-topics parking convention (`open-topics.md`), and naming convention (`naming.md`). Consult them before branching, opening a PR, or releasing.
- **Dev automation skills** live in `.claude/skills/`: `/release`, `merge-pr`, and `dependabot`.

## Project Structure

```
plugin/                         — source of truth (the installable plugin)
  .claude-plugin/plugin.json    — plugin manifest
  commands/*.md                 — /pkb + /pkb:* command specs (incl. the fuzzy router)
  skills/pkb-manager/
    SKILL.md                    — skill manifest (hub resolution, principles, guardian)
    references/*.md             — operation specs (hub-resolution, archive, doctor, audit, …)
.claude-plugin/marketplace.json — local marketplace entry (install from this checkout)
.claude/
  rules/*.md                    — repo workflow conventions
  skills/*                      — dev automation skills (release, merge-pr, dependabot)
  settings.json                 — enabled plugins
pkb.py                          — deterministic no-LLM doctor/archive CLI
tests/                          — structural tests + fixtures + behavioral evals
docs/iterations-history.md      — per-iteration changelog
```

## Release Process

Run the `/release` skill (`.claude/skills/release/`). It runs the structural test gate, bumps the version across every `version_files` entry, opens a `develop → main` PR, tags `v<version>`, creates the GitHub Release, and back-merges `main` into `develop`. See `.claude/rules/branch-workflow.md` for the branch model.

## Project State Notes

Per-iteration changelog: [`docs/iterations-history.md`](docs/iterations-history.md). How to maintain it: [`.claude/rules/iterations-history.md`](.claude/rules/iterations-history.md).
