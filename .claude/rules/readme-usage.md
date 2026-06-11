# README command documentation

The user-facing commands must stay documented in `README.md`:

- Every `/pkb` and `/pkb:*` command and its flags belongs in the **Commands** section.
- Every `pkb.py` subcommand (the deterministic, no-LLM CLI) belongs in the usage examples.

When you add or change a command or flag in `plugin/commands/`, in the `pkb-manager` skill, or in `pkb.py`, update the matching `README.md` section in the **same change**, so the documentation never drifts from the actual behavior. The `mdformat` pre-commit hook owns the README table of contents — don't hand-edit it.
