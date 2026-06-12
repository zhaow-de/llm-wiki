## 0.0.1 (2026-06-12)

### 🔧 CI/Build

#### Fix behavioral eval CI environment (SDK package + sandbox fallback)

Fixed the behavioral evaluation CI job, which was failing before running any test. The promptfoo provider package now resolves correctly, and the Claude Code sandbox gracefully falls back to unsandboxed execution on CI runners that lack the required system tools (`bubblewrap`/`socat`).

*[#1](https://github.com/zhaow-de/llm-wiki/pull/1) by @zhaow-de*

## v0.0.0 (2026-06-12)


- chore: initial commit
- Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Reviewed-by: Claude Fable 5 <noreply@anthropic.com>
