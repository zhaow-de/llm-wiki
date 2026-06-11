---
name: release
description: Cut a release — run the structural test suite, bump the version on develop, open a PR into main, merge it, push the v<version> tag, create the GitHub Release, and back-merge main into develop
disable-model-invocation: false
model: sonnet
allowed-tools: Bash(git add:*), Bash(git checkout:*), Bash(git tag:*), Bash(git status:*), Bash(git commit:*), Bash(git push:*), Bash(git pull:*), Bash(git fetch:*), Bash(git merge:*), Bash(git log:*), Bash(git branch:*), Bash(gh pr:*), Bash(gh release:*), Bash(cz:*), Bash(uv:*), Bash(python3:*), Bash(sleep:*), Bash(./tests/test-plugin-validate.sh:*), Bash(./tests/test-structure.sh:*), Bash(./tests/test-local-cli-doctor.sh:*), Read, Edit, Write
---

Cuts a release PR from `develop` to `main`, then pushes the `v<version>` tag and creates the GitHub Release directly from this skill. After the release is published, the skill back-merges `main` into `develop` to keep them in lock-step.

This is a Claude Code plugin. The version lives in five places kept in lock-step by commitizen's `version_files`: `.cz.toml`, `pyproject.toml`, the README `Version` badge, `plugin/.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json`.

## Context

- Current branch: !`git branch --show-current`
- Current version: !`cz version --project`
- Prerequisites: !`which cz && which gh && which python3 && which uv && echo "all found" || echo "MISSING tools"`

## Instructions

1. **Verify prerequisites** from the context above. If not on `develop`, ask the user to switch branches first. If any tool is missing (`cz`, `gh`, `python3`, `uv`), report and stop. `cz` is installed with `brew install commitizen`. Confirm `gh auth status` succeeds — if it returns 401, ask the user to run `gh auth refresh -h github.com` first.

2. **Run the structural test suite as a release gate** — these are the deterministic, no-LLM checks. All must pass before bumping:
   ```bash
   ./tests/test-plugin-validate.sh
   ./tests/test-structure.sh
   ./tests/test-local-cli-doctor.sh
   ```
   If any fails, stop and report — do not release. For releases that change command behavior, also run the deeper editorial `/pkb:doctor` and a manual `/pkb status` smoke check in a fresh Claude Code session, and exercise the changed `/pkb:*` subcommand before continuing.

3. **Update develop and verify it is synced with main**:
   ```bash
   git pull origin develop
   git fetch origin main
   ```

   Check for drift — if `main` has commits not on `develop`, a release or hotfix landed on `main` without being back-merged. Releasing now would re-introduce conflicts (version files, `CHANGELOG.md`, files modified-on-main but deleted-on-develop).

   ```bash
   git log develop..origin/main --oneline
   ```

   If this shows any commits, drift exists. Use `AskUserQuestion` to ask whether to resolve it now by merging `main` into `develop`, or to abort:
   - Show the drifting commits (so the user can see what's about to come in).
   - Options: "Yes, back-merge main → develop now" / "Abort, I'll handle it manually".

   **If the user chooses to back-merge:**
   ```bash
   git merge origin/main --no-edit
   ```

   - If the merge succeeds cleanly, push `git push origin develop`, then continue to step 4.
   - If the merge fails with conflicts, do **not** push. Investigate each conflicted file, propose a resolution to the user (typical patterns: version files → take whichever is newer / about-to-be-bumped; `CHANGELOG.md` → keep both entries chronologically; modified-on-main but deleted-on-develop → confirm the fix exists in the replacement code, then keep the deletion), apply it, commit the merge, and push. Only then continue.

   **If the user chooses to abort:** stop and report — do not proceed.

4. **Create the release branch**:
   ```bash
   git checkout -b "release/$(date +%Y%m%d-%H%M%S)"
   ```

5. **Bump the version files and generate the raw changelog** — `--files-only`, so nothing is committed or tagged yet:
   ```bash
   cz bump --yes --changelog --files-only
   ```

   This updates every `version_files` entry (`pyproject.toml`, the README `Version` badge, `plugin/.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json`), bumps `.cz.toml`, and writes the raw commit list to `CHANGELOG.md`. With `--files-only` it does **not** commit or tag — the skill makes one commit and creates the `v<version>` tag in step 10, after the changelog is rewritten (step 9) and `uv.lock` is refreshed (step 6).

   > Prerequisite: commitizen must be configured — this repo's `.cz.toml` lists all five `version_files`. Set it up before running `/release` if missing.

6. **Refresh `uv.lock` to record the new version**:
   ```bash
   uv lock
   ```
   `cz bump` does not touch `uv.lock`; without this step the lockfile would silently drift behind `pyproject.toml`. The change is uncommitted at this point; step 10 commits it together with the version bump and changelog.

7. **Verify every `version_files` entry was actually bumped**:

   `cz bump` silently skips a `version_files` entry whose line no longer contains the previous version string (drift from a past bad bump). A silent skip would leave one of the five files behind.

   ```bash
   NEW_VERSION=$(cz version --project)
   python3 - "$NEW_VERSION" <<'PY'
   import json, pathlib, re, sys
   new = sys.argv[1]
   errs = []
   pp = pathlib.Path("pyproject.toml").read_text()
   m = re.search(r'^version\s*=\s*"([^"]+)"', pp, re.M)
   if not (m and m.group(1) == new): errs.append(f"pyproject.toml: {m and m.group(1)}")
   rd = pathlib.Path("README.md").read_text()
   m = re.search(r'badge/version-v([0-9]+\.[0-9]+\.[0-9]+)', rd)
   if not (m and m.group(1) == new): errs.append(f"README badge: {m and m.group(1)}")
   pj = json.loads(pathlib.Path("plugin/.claude-plugin/plugin.json").read_text())
   if pj.get("version") != new: errs.append(f"plugin.json: {pj.get('version')}")
   mp = json.loads(pathlib.Path(".claude-plugin/marketplace.json").read_text())
   if mp.get("version") != new: errs.append(f"marketplace.json top: {mp.get('version')}")
   for p in mp.get("plugins", []):
       if p.get("version") != new: errs.append(f"marketplace.json plugin {p.get('name')}: {p.get('version')}")
   if errs:
       print("ERROR: cz bump did not bump every version file to", new)
       for e in errs: print("  -", e)
       print("Stop and investigate — do NOT push. Likely cause: a file's version drifted from .cz.toml in a past release, so cz's find-and-replace cannot locate the old value. Fix the stale line by hand, re-run cz bump, or hand-edit to the new version.")
       sys.exit(1)
   print("All version files at", new)
   PY
   ```

   If this fails, stop and report — do not proceed.

8. **Fetch PR data for the changelog**:
   ```bash
   python3 ${CLAUDE_SKILL_DIR}/scripts/fetch-pr-data.py ${CLAUDE_SESSION_ID}
   ```

9. **Generate the user-friendly changelog**:

   Read the PR data from `/tmp/release_pr_data_${CLAUDE_SESSION_ID}.json` and follow the format and guidelines in [changelog-format.md](changelog-format.md). Replace the raw commit list `cz bump` wrote into `CHANGELOG.md` with the user-friendly section for the new version at the top, and **preserve all previous version sections below it**.

   Keep that new-version section text — step 17 passes the same content to `gh release create --notes` as the Release description, so it never needs to live in the repo as a separate file.

10. **Commit the release and create the tag**:
    ```bash
    VERSION=$(cz version --project)
    git add .cz.toml pyproject.toml README.md CHANGELOG.md uv.lock plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
    git commit -m "chore(release): bump version to v$VERSION"
    git tag "v$VERSION"
    ```

    One commit carries the version bump, changelog, and refreshed lockfile; the `v<version>` tag points at it. Remember `VERSION` for the remaining steps.

11. **Push the release branch**:
    ```bash
    git push origin "$(git branch --show-current)"
    ```

12. **Create the PR** with `gh pr create` targeting `main`, using the description template from [pr-description.md](pr-description.md) (fill in `{version}` with `VERSION`). Include flags `--base main`, `--title "Release v<VERSION>"`, `--assignee @me`, and pass the filled template via `--body-file` (or `--body`).

13. **Store the PR number and URL** from the output of step 12. The PR URL ends in the number (e.g. `.../pull/63` means PR number `63`).

14. **Return to develop**:
    ```bash
    git checkout develop
    ```

15. **Auto-merge the release PR** with a merge commit (preserving the tagged bump commit on `main`). The skill does not pause to ask the user — releases run end-to-end. Stop only if something is genuinely worth attention: the PR has conflicts, or it was closed without merging. Otherwise poll every 30 seconds and merge as soon as GitHub reports the PR mergeable and not blocked by branch protection:
    ```bash
    PR_NUMBER=<the PR number from step 13>

    while true; do
        pr_state=$(gh pr view "$PR_NUMBER" --json state -q .state)
        pr_mergeable=$(gh pr view "$PR_NUMBER" --json mergeable -q .mergeable)
        pr_state_status=$(gh pr view "$PR_NUMBER" --json mergeStateStatus -q .mergeStateStatus)
        if [ "$pr_state" = "MERGED" ]; then
            echo "PR merged!"
            break
        elif [ "$pr_state" = "CLOSED" ]; then
            echo "PR was closed without merging — stop"
            exit 1
        elif [ "$pr_mergeable" = "CONFLICTING" ]; then
            echo "PR has conflicts — stop, do not merge"
            exit 1
        elif [ "$pr_mergeable" = "MERGEABLE" ] && [ "$pr_state_status" != "BLOCKED" ]; then
            gh pr merge "$PR_NUMBER" --merge --delete-branch && break
        fi
        echo "Waiting for PR to be ready... (state: $pr_state, mergeable: $pr_mergeable, status: $pr_state_status)"
        sleep 30
    done
    ```

16. **Push the release tag** so it points at the bump commit now on `main`. The tag was created in step 10 and persists across the branch switch.
    ```bash
    git push origin "v<VERSION>"
    ```

17. **Create the GitHub Release** directly, passing the new version's changelog section (from step 9, also at the top of `CHANGELOG.md`) inline as the description:
    ```bash
    gh release create "v<VERSION>" --title "v<VERSION>" --notes "<new version's CHANGELOG.md section>" --verify-tag
    ```
    `--verify-tag` aborts if the tag was not pushed in step 16. The command prints the Release URL — keep it for the final report.

18. **Back-merge `main` → `develop` via a PR.** This repo's `develop` is protected against direct pushes, so the back-merge cannot be a plain `git push`. Cut a dedicated `chore/back-merge-v<VERSION>` branch off `origin/main`, push it, open the PR, then auto-merge with the same poll-then-merge loop as step 15:
    ```bash
    git fetch origin main
    BACKMERGE_BRANCH="chore/back-merge-v<VERSION>"
    git checkout -b "$BACKMERGE_BRANCH" origin/main
    git push -u origin "$BACKMERGE_BRANCH"
    BACKMERGE_URL=$(gh pr create --base develop --head "$BACKMERGE_BRANCH" \
        --title "chore(config): back-merge v<VERSION> into develop" \
        --body "Back-merge of the \`v<VERSION>\` release commit from \`main\` into \`develop\` so the two branches stay in lock-step per \`.claude/rules/branch-workflow.md\`. Auto-opened by the \`/release\` skill.")
    BACKMERGE_NUMBER=$(echo "$BACKMERGE_URL" | sed -E 's|.*/pull/([0-9]+)|\1|')

    while true; do
        pr_state=$(gh pr view "$BACKMERGE_NUMBER" --json state -q .state)
        pr_mergeable=$(gh pr view "$BACKMERGE_NUMBER" --json mergeable -q .mergeable)
        pr_state_status=$(gh pr view "$BACKMERGE_NUMBER" --json mergeStateStatus -q .mergeStateStatus)
        if [ "$pr_state" = "MERGED" ]; then
            echo "Back-merge PR merged!"
            break
        elif [ "$pr_state" = "CLOSED" ]; then
            echo "Back-merge PR was closed without merging — stop"
            exit 1
        elif [ "$pr_mergeable" = "CONFLICTING" ]; then
            echo "Back-merge PR has conflicts — stop, do not merge"
            exit 1
        elif [ "$pr_mergeable" = "MERGEABLE" ] && [ "$pr_state_status" != "BLOCKED" ]; then
            gh pr merge "$BACKMERGE_NUMBER" --merge --delete-branch && break
        fi
        echo "Waiting for back-merge PR... (state: $pr_state, mergeable: $pr_mergeable, status: $pr_state_status)"
        sleep 30
    done
    ```

19. **Local cleanup** — fast-forward both branches against their remotes, drop the throwaway release **and** back-merge branches, and prune stale tracking refs:
    ```bash
    git checkout develop
    git pull --ff-only origin develop
    git checkout main
    git pull --ff-only origin main
    git checkout develop
    git branch -d release/<timestamp from step 4>
    git branch -d chore/back-merge-v<VERSION>
    git fetch --all --prune
    ```

    Both `git branch -d` calls succeed because each branch is fully integrated via its merge commit. If either errors "not fully merged" while its PR shows merged and the remote head is gone, the work is integrated — `git branch -D` is then safe.

20. **Report success** with the release PR URL, the GitHub Release URL (printed by step 17), and the back-merge PR URL. The Release description is the new version's changelog section; the full history lives in `CHANGELOG.md`.

## Notes

- If any step fails, stop and report the error to the user.
- The `--yes` flag on `cz bump` auto-confirms the version bump.
- Auto-merge in steps 15 and 18 uses `--merge` — never switch to `--squash` or `--rebase`, which would lose the bump-commit-tagged invariant on `main`.
- Do not use composite commands — they always force a permission request from the user.
- You are already in the repo folder — do not `cd` first (redundant, and can cause a composite command).
