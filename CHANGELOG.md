## 0.1.2 (2026-06-15)

### 🐛 Bug Fixes

#### C13 aliases for early-session field names

`doctor --fix` now rewrites four non-canonical field names written by early ingestion sessions (`source_url`, `date_ingested`, `source_type`, `url`) to their canonical forms (`source`, `ingested`, `type`, `source`), instead of only warning. Run `doctor --fix` once on any existing wiki to clean up legacy frontmatter automatically.

*[#12](https://github.com/zhaow-de/llm-wiki/pull/12) by @zhaow-de*

#### Real wall-clock time tracking for `--min-time` research sessions

Multi-round research sessions now read the actual system clock (`bash date +%s`) to measure elapsed time, rather than estimating it. Early completion now also requires at least 75% of the declared budget to have elapsed — a high progress score alone can no longer cut a session short before the user's time investment is honoured.

*[#12](https://github.com/zhaow-de/llm-wiki/pull/12) by @zhaow-de*

## 0.1.1 (2026-06-12)

### 🐛 Bug Fixes

#### iter-10 — fix index sync and rename to llm-wiki-pkb

Fixed three spec bugs where agents could silently skip raw source files during compilation: leaf directory indexes (`raw/articles/`, `raw/papers/`, etc.) were documented as optional updates rather than required ones, letting them drift out of sync without any error. Also corrects the plugin display name from `llm-wiki pkb` to `llm-wiki-pkb` and updates the `install-commands` wrapper template so future runs stamp the correct `(llm-wiki-pkb)` prefix on local command descriptions.

*[#9](https://github.com/zhaow-de/llm-wiki/pull/9) by @zhaow-de*

## 0.1.0 (2026-06-12)

### 🚀 Features

#### install-commands for /pkb-* user aliases
Add `/pkb:install-commands`, a one-time setup command that writes wrapper files to `~/.claude/commands/` so all wiki commands are accessible as bare `/pkb` and `/pkb-*` slash commands — no `pkb:` namespace prefix required. Supports `--dry-run` to preview changes. Re-run after plugin updates to sync new or removed commands.

*[#4](https://github.com/zhaow-de/llm-wiki/pull/4) by @zhaow-de*

### 🐛 Bug Fixes

#### avoid $ARGUMENTS substitution in install-commands body
Fixed a silent failure where `/pkb:install-commands` would load but never write any wrapper files. The skill instruction was corrupted at invocation time by Claude Code's `$ARGUMENTS` substitution, producing a contradictory directive that caused the executor to skip all Write tool calls.

*[#6](https://github.com/zhaow-de/llm-wiki/pull/6) by @zhaow-de*

### 📦 Other Changes

#### update displayName to llm-wiki pkb
Renamed the plugin display name from "llm-wiki personal knowledge base" to "llm-wiki pkb".

*[#5](https://github.com/zhaow-de/llm-wiki/pull/5) by @zhaow-de*

## 0.0.1 (2026-06-12)

### 🔧 CI/Build

#### Fix behavioral eval CI environment (SDK package + sandbox fallback)

Fixed the behavioral evaluation CI job, which was failing before running any test. The promptfoo provider package now resolves correctly, and the Claude Code sandbox gracefully falls back to unsandboxed execution on CI runners that lack the required system tools (`bubblewrap`/`socat`).

*[#1](https://github.com/zhaow-de/llm-wiki/pull/1) by @zhaow-de*

## v0.1.2 (2026-06-15)


- Merge pull request #12 from zhaow-de/fix/c13-aliases-and-research-clock
- fix(references,commands): C13 aliases and real-clock time tracking for --min-time
- fix(commands,references): enforce real wall-clock time tracking in --min-time sessions
- Replace estimation-based time checks with actual clock reads: run
`bash date +%s` at session start and after each round, store epochs in
.research-session.json. Early-completion trigger now requires elapsed ≥ 75%
of the declared budget so a high progress score alone cannot cut a session
short before the user's time investment is respected.
- Also fixes a self-contradictory paragraph in C13 (doctor.md) where "When
the tables are empty" was left as the opener after the table received four
entries.
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- fix(references): add C13 key-alias table entries for early-session field names
- Four aliases added: source_url→source, date_ingested→ingested,
source_type→type, url→source. These were used by early ingest sessions
before the canonical field names were settled; doctor --fix now rewrites
them instead of only warning.
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- Merge pull request #11 from zhaow-de/chore/back-merge-v0.1.1
- chore(config): back-merge v0.1.1 into develop
- Merge pull request #10 from zhaow-de/release/20260612-233858
- Release v0.1.1

## v0.1.1 (2026-06-12)


- Merge pull request #9 from zhaow-de/fix/index-sync-and-displayname
- fix(references,commands,config): iter-10 — fix index sync and rename to llm-wiki-pkb
- fix(commands,config): rename displayName to llm-wiki-pkb and prefix wrapper descriptions
- - plugin.json and marketplace.json: displayName "llm-wiki pkb" → "llm-wiki-pkb"
  (consistent with the repo naming convention in .claude/rules/naming.md)
- install-commands.md: add "(llm-wiki-pkb)" prefix to wrapper description
  template so future /pkb-install-commands runs stamp local aliases correctly
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
- Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- fix(references): fix raw sub-directory index sync and guardian check scope
- - ingestion.md: correct step 2 — raw/_index.md uses category counts, not
  per-file rows; mark raw/{type}/_index.md update as required (not best-effort)
  because agents use it during compilation to discover sources
- indexing.md: split "best-effort" scope: leaf directory indexes (raw/{type}/,
  wiki/{category}/) are required updates; aggregate indexes (raw/_index.md,
  wiki/_index.md, master) remain best-effort
- SKILL.md: expand guardian check step 2 to explicitly cover both leaf and
  aggregate index levels so the auto-fix fires at the right granularity
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
- Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- Merge pull request #8 from zhaow-de/chore/back-merge-v0.1.0
- chore(config): back-merge v0.1.0 into develop
- Merge pull request #7 from zhaow-de/release/20260612-170638
- Release v0.1.0

## v0.1.0 (2026-06-12)


- chore(release): bump version to v0.1.0
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
- Merge pull request #6 from zhaow-de/fix/install-commands-args-substitution
- fix(commands): avoid $ARGUMENTS substitution in install-commands body
- fix(commands): avoid $ARGUMENTS substitution in install-commands body
- The instruction "i.e. write \`$ARGUMENTS\` literally" had $ARGUMENTS
substituted to empty string when the skill was invoked with no args,
producing the contradictory "write \`\` literally" which caused the
executor to skip writing wrappers entirely.
- Replace with a plain-English description that avoids the token:
"a dollar sign $ immediately followed by ARGUMENTS" — unambiguous
regardless of invocation arguments.
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- Merge pull request #5 from zhaow-de/chore/fix-display-name
- chore(config): update displayName to llm-wiki pkb
- chore(config): update displayName to llm-wiki pkb
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- Merge pull request #4 from zhaow-de/feat/install-commands
- feat(commands): iter-4 — install-commands for /pkb-* user aliases
- docs(readme): reformat Examples code block with per-command comments
- Change the code fence language to shell for syntax highlighting and
split each inline trailing comment onto its own preceding line, with
a blank line between entries for readability.
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- feat(commands): add install-commands to expose /pkb-* user aliases
- Add /pkb:install-commands skill that syncs wrapper files into
~/.claude/commands/, registering /pkb and /pkb-* as bare slash commands
available without the pkb: namespace prefix. The skill handles full
sync: creates/overwrites current wrappers and deletes stale ones from
previous plugin versions.
- Update README to document the one-time setup step and replace all
/pkb:* invocations with /pkb-* throughout the user-facing sections.
Update naming.md and readme-usage.md to reflect the new invocation
convention.
- Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Reviewed-by: Claude Sonnet 4.6 <noreply@anthropic.com>
- Merge pull request #3 from zhaow-de/chore/back-merge-v0.0.1
- chore(config): back-merge v0.0.1 into develop
- Merge pull request #2 from zhaow-de/release/20260612-153932
- Release v0.0.1

## v0.0.1 (2026-06-12)


- chore(release): bump version to v0.0.1
- Merge pull request #1 from zhaow-de/ci/behavioral-eval-sdk-package
- ci: fix behavioral eval CI environment (SDK package + sandbox fallback)
- ci(tests): fall back to unsandboxed eval when bwrap/socat unavailable
- The behavioral eval's anthropic:claude-agent-sdk provider enables the Claude Code sandbox, which needs bubblewrap (bwrap) and socat. GitHub's ubuntu-latest runner has neither, so every test aborted with 'Sandbox required but unavailable'. Set sandbox.failIfUnavailable=false so the eval sandboxes wherever the deps exist (e.g. local) and degrades to unsandboxed execution on CI runners that lack them. Bash stays gated by the explicit settings.permissions.allow list, and the runner is already an ephemeral isolated VM.
- Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Reviewed-by: Claude Opus 4.8 <noreply@anthropic.com>
- ci: install claude-agent-sdk locally for behavioral eval provider
- The behavioral eval uses the promptfoo anthropic:claude-agent-sdk provider, which requires @anthropic-ai/claude-agent-sdk to be resolvable from the repo root. The workflow installed @anthropic-ai/claude-code globally instead, so promptfoo could not resolve the provider package and every eval errored with a resolution failure. Install the SDK package locally (non -g) so it lands on the node_modules resolution path; the SDK bundles the Claude Code runtime it spawns, so the separate global install is no longer needed.
- Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Reviewed-by: Claude Opus 4.8 <noreply@anthropic.com>

## v0.0.0 (2026-06-12)


- chore: initial commit
- Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Reviewed-by: Claude Fable 5 <noreply@anthropic.com>
