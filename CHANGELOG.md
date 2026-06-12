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
