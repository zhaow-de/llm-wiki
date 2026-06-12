---
description: "Install /pkb and /pkb-* slash commands into ~/.claude/commands/ so they work without the pkb: namespace prefix. Run once after plugin installation; re-run after plugin updates to sync new and removed commands."
argument-hint: "[--dry-run]"
allowed-tools: Read, Write, Bash(ls:*), Bash(find:*), Bash(rm:*), Bash(mkdir:*)
---

## Task

Write wrapper files to `~/.claude/commands/` that expose plugin commands as bare slash commands — `/pkb`, `/pkb-ingest`, `/pkb-research`, etc. — without requiring the `pkb:` namespace prefix. Sync the directory: create or overwrite current wrappers and delete stale ones from previous plugin versions.

If `$ARGUMENTS` contains `--dry-run`, print the planned changes without writing or deleting any files.

## Wrapper name mapping

| Source in `${CLAUDE_PLUGIN_ROOT}/commands/` | Wrapper in `~/.claude/commands/` | Skill invoked |
| ------------------------------------------- | --------------------------------- | ------------- |
| `pkb.md`                                    | `pkb.md`                          | `pkb:pkb`     |
| `<name>.md` (all others)                    | `pkb-<name>.md`                   | `pkb:<name>`  |

## Steps

**1. Ensure the target directory exists** (skip in `--dry-run`):

```bash
mkdir -p ~/.claude/commands
```

**2. Enumerate command source files:**

```bash
ls "${CLAUDE_PLUGIN_ROOT}/commands/"*.md
```

For each file, use the `Read` tool to extract these fields from its YAML frontmatter (the block between the first `---` pair at the top of the file):

- `description` — required
- `argument-hint` — optional; may be absent

Build a list of records: `{ source_basename, wrapper_basename, skill_ref, description, argument_hint }`.

**3. Delete stale wrappers:**

```bash
find ~/.claude/commands -maxdepth 1 -name 'pkb*.md' -type f
```

Any file whose basename does NOT appear in the current wrapper list is stale. In `--dry-run`, print `  would delete: <basename>`. Otherwise:

```bash
rm ~/.claude/commands/<stale-basename>
```

**4. Write wrapper files:**

For each record, write `~/.claude/commands/<wrapper_basename>` using the `Write` tool.

When `argument-hint` is present, the file content is:

```
---
description: (llm-wiki-pkb) <description>
argument-hint: <argument-hint>
---

Use the `<skill_ref>` skill with these arguments: <ARGS_PLACEHOLDER>
```

When `argument-hint` is absent:

```
---
description: (llm-wiki-pkb) <description>
---

Use the `<skill_ref>` skill with these arguments: <ARGS_PLACEHOLDER>
```

Replace `<ARGS_PLACEHOLDER>` with the Claude Code arguments token: a dollar sign `$` immediately followed by the word `ARGUMENTS` (all caps, no space). Write it literally as a seven-character token — do not evaluate it. Claude Code substitutes this token at invocation time with whatever the user types after the command name.

In `--dry-run`, print `  would write: <wrapper_basename>` instead of writing.

**5. Print summary:**

```
Installed / updated:
  pkb.md
  pkb-archive.md
  pkb-assess.md
  ... (one line per wrapper written or overwritten)

Removed (stale):
  (none)   ← or list deleted filenames

Available commands:
  /pkb                    /pkb-audit              /pkb-collect
  /pkb-archive            /pkb-compile            /pkb-dataset
  ... (three-column layout, sorted)

Re-run /pkb-install-commands after plugin updates to keep aliases in sync.
```
