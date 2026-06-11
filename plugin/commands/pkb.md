---
description: "LLM wiki knowledge base — understands natural language. Say what you want (add a URL, import a collection, collect a catalog, track inventory, index a dataset, archive an old topic, ask a question, research a topic, audit an output, resume work) and it routes to the right subcommand. Also handles init, status, and config."
argument-hint: "[<natural language request>] [init <topic-name> [--local]] [config hub-path [<path>]] [--wiki <name>]"
allowed-tools: Skill, Read, Write, Edit, Glob, Bash(ls:*), Bash(wc:*), Bash(mkdir:*), Bash(date:*), Bash(mv:*)
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`) and prefer that path; use `resolved_path` only as a fallback cache when the expanded `hub_path` is unavailable and `resolved_path` is initialized. If config has only `resolved_path`, use it. If the configured path can be statted but reading `wikis.json` or listing `topics/` fails with `Operation not permitted`, stop and ask the user to grant Full Disk Access/iCloud Drive access to the launcher; do not fall back to `~/llm-wiki-data` or `resolved_path`. Do not write machine-specific `resolved_path` into shared configs.
2. If no config → read `$HOME/llm-wiki-data/_index.md`. If it exists → HUB = `$HOME/llm-wiki-data`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.llm-wiki-data/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup with portable path resolution (`<HUB>`, `~`, absolute, or HUB-relative); if the registry path is stale, fall back to `HUB/topics/<name>`; CWD has `.llm-wiki-data/` → use it; else → HUB.
4. Read `<wiki>/_index.md` if found. Variant: **wiki-neutral** — `pkb.md` is the router, init, and config command, so "wiki missing" is not always an error; the init subcommand creates the wiki, status shows an empty hub gracefully, and the natural-language router explains how to create one.

You are the llm-wiki knowledge base manager. Read the skill at `skills/pkb-manager/SKILL.md` and structure reference at `skills/pkb-manager/references/wiki-structure.md` for full conventions.

---

### If $ARGUMENTS starts with the word "init"

(The keyword must be the first standalone token — "what was the initial setup?" is freeform text for the router below, not an init request.)

Initialize a new wiki. Parse arguments:
- `init <name>` → create topic wiki at `HUB/topics/<name>/`
- `init <name> --local` → create local wiki at `.llm-wiki-data/` in current project
- `init` (no name) → ask: "What topic is this for?" Then create the topic wiki with their answer.

**A topic name is always required.** There is no bare global wiki — HUB is only a hub (wikis.json + _index.md + log.md). All content lives in topic sub-wikis.

**Steps:**

1. If HUB doesn't exist yet, create the hub first:
   - `HUB/wikis.json` (empty registry)
   - `HUB/_index.md` (hub index with empty topic wiki table)
   - `HUB/log.md` (global activity log)
   - `HUB/topics/` directory
   - `HUB/.obsidian/` with the minimal vault config (the three JSON files shown in step 3).
   - NO `raw/`, `wiki/`, `inventory/`, `datasets/`, `output/`, `inbox/`, or `config.md` at the hub level.

2. Create the core topic wiki directory structure:
   - `inbox/`, `inbox/.processed/`
   - `raw/`, `raw/articles/`, `raw/papers/`, `raw/repos/`, `raw/notes/`, `raw/data/`
   - `wiki/`, `wiki/concepts/`, `wiki/topics/`, `wiki/references/`, `wiki/theses/`
   - `output/`
   - Do not create `inventory/` or `datasets/` during init. Those layers are
     created lazily by `/pkb:inventory`, `/pkb:dataset`, or the checkup when a
     partially existing layer needs repair.
   - For local wikis (`--local`): append `.llm-wiki-data/` to the project's `.gitignore`.

3. **Obsidian vault.** The single vault lives at the **hub root** (created in step 1 above). Hub-based topic wikis are folders inside that vault and get **no** `.obsidian/` of their own. **Only for `--local` wikis** (which have no hub), create `.obsidian/` at the local wiki root (`.llm-wiki-data/.obsidian/`) with the minimal vault config below:
   - `.obsidian/app.json`:
     ```json
     {
       "showFrontmatter": true,
       "alwaysUpdateLinks": true,
       "newLinkFormat": "relative",
       "useMarkdownLinks": false
     }
     ```
   - `.obsidian/appearance.json`:
     ```json
     {
       "accentColor": ""
     }
     ```
   - `.obsidian/graph.json`:
     ```json
     {
       "collapse-filter": false,
       "search": "",
       "showTags": true,
       "showAttachments": false,
       "showOrphans": true,
       "collapse-color-groups": false,
       "collapse-display": false,
       "showArrow": true,
       "textFadeMultiplier": 0,
       "nodeSizeMultiplier": 1,
       "lineSizeMultiplier": 1
     }
     ```

4. Create empty `_index.md` only in the directories created during init,
   following the format in `references/wiki-structure.md`. Use today's date.
   Set all counts to 0. Do not write empty indexes for optional layers that do
   not exist yet.

5. Create `log.md` with initial entry:
   ```
   # Wiki Activity Log

   ## [YYYY-MM-DD] init | Wiki initialized
   ```

6. Ask the user: "What is this wiki about?" Use their answer to create `config.md` with title, description, scope, and today's date.

7. Before registering, check both `HUB/topics/<slug>/` and
   `HUB/topics/.archive/<slug>/`, plus any `wikis.json` entry with that slug.
   If an archived topic already exists, stop and ask whether to restore it with
   `/pkb:archive restore <slug>` or choose a different slug. Do not silently
   create a new active topic over an archived topic boundary.

8. Register in `HUB/wikis.json` with a portable relative path (`topics/<slug>`) and update hub `_index.md` topic wiki table. For local wikis, add to the `local_wikis` array with its absolute local path.

9. Report what was created and suggest:
   - `/pkb:research "topic" --sources 10` — auto-research to bootstrap
   - `/pkb:ingest <url|file|text>` — add source material
   - `/pkb:ingest-collection <repo|wiki-dump>` — bulk import a bounded upstream collection
   - `/pkb:collect "<things>"` — find, dedupe, and catalog examples, artifacts, tools, memes, or source candidates
   - `/pkb:inventory add ingest-candidate "title"` — track a candidate, corpus, entity, or next action
   - `/pkb:dataset add "title" --location <path-or-url>` — index a large/external dataset
   - `/pkb:compile` — compile sources into wiki articles
   - `/pkb:query <question>` — ask questions

---

### If $ARGUMENTS is freeform text (not "init", "config", or empty) and a wiki exists

The user typed something that isn't a known keyword. Detect their intent and route to the right subcommand.

**Check these patterns in order — first match wins:**

| Priority | Intent | Signal patterns | Route to |
|----------|--------|----------------|----------|
| 0 | **Collection Ingest** | Words: "import wiki", "mirror wiki", "bulk ingest", "ingest collection", "import collection", "ingest repo", "import repo"; or a URL/path plus collection signals: `dump.xml`, `.xml.bz2`, `.xml.gz`, `api.php`, `MediaWiki`, `github.com/*/*` with "all", "repo", "docs", "BIPs", or "collection" | `Skill: pkb:ingest-collection` with the source and filters |
| 0b | **Collect** | "collect", "collector", "catalog", "curate", "gather examples", "find all", "make a list of", "inventory all", "find and inventory", "collect and inventory"; especially with object words like "memes", "tools", "projects", "examples", "companies", "people", "quotes", "assets", "images", "videos", "screenshots" | `Skill: pkb:collect` |
| 1 | **Inventory** | "inventory", "ingest queue", "source queue", "candidate list", "watch list", "backlog", "track this", "keep inventory", "what should become inventory", "migrate output to inventory" | `Skill: pkb:inventory` |
| 2 | **Dataset** | "dataset", "large data", "too big for the wiki", "index this data", "data registry", "dataset manifest", "corpus manifest", "external data", "query this dataset", "profile dataset" | `Skill: pkb:dataset` |
| 3 | **Ingest** | Contains a URL (`http://`, `https://`), a file path (`/`, `~/`), or words: "add", "save", "ingest", "read this", "grab this" | `Skill: pkb:ingest` with the URL/path/text |
| 4 | **Resume** | "where was I", "pick up where", "continue", "resume", "get back to", "catch me up", "what was I working on" | `Skill: pkb:query` with `--resume` |
| 5 | **Audit** | "audit", "full audit", "can I trust", "trust this", "verify this output", "verify this report", "fact-check this artifact", "check everything", "provenance", "drift report", "follow the evidence", "find the truth" | `Skill: pkb:audit` |
| 5b | **Thesis** | "prove that", "is it true that", "verify", "test the claim", "test the hypothesis" — checked before Query because thesis phrasings usually contain "?" too ("is it true that X?") | `Skill: pkb:research` with `--mode thesis "<claim>"` |
| 6 | **Query** | Starts with what/why/how/when/where/who, contains "?", or words: "tell me about", "explain", "what do we know about" | `Skill: pkb:query` with the question |
| 7 | **Research** | "research", "find out about", "look into", "deep dive", "investigate" | `Skill: pkb:research` with the topic |
| 9 | **Compile** | "compile", "process sources", "synthesize", "update articles" | `Skill: pkb:compile` |
| 10 | **Doctor** | "check health", "fix wiki", "broken", "problems", "cleanup" | `Skill: pkb:doctor` |
| 10b | **Librarian** | "librarian", "quality scan", "scan quality", "article quality", "content review", "keep the wiki in check", "review articles", "librarian report", "quality report", "stale articles" | `Skill: pkb:librarian` |
| 10c | **Refresh** | "check freshness", "still current", "up to date", "outdated", "refresh" | `Skill: pkb:refresh` |
| 11 | **Output** | "write a summary", "generate a report", "slides", "create a", "write a" | `Skill: pkb:output` with the request |
| 12 | **Assess** | "compare to", "assess", "gap analysis" | `Skill: pkb:assess` |
| 13 | **Plan** | "plan for", "implementation plan", "architecture for" | `Skill: pkb:plan` |
| 13b | **Lessons Learned** | "learn this", "learn that", "lesson learned", "lessons learned", "absorb this", "capture what we learned", "what did we learn", "session takeaways", "ll" | `Skill: pkb:ll` with the topic hint |
| 14 | **Retract** | "remove source", "retract", "delete source", "pull out" | `Skill: pkb:retract` |
| 15 | **Project (new)** | "new project", "start a project", "create project" (+ slug and goal) | `Skill: pkb:project` with `new <slug> "goal"` |
| 16 | **Project (list)** | "list projects", "what projects", "show projects", "my projects" | `Skill: pkb:project` with `list` |
| 17 | **Project (show)** | "show project X", "what's in project X", "open project X" | `Skill: pkb:project` with `show <slug>` |
| 18 | **Project (archive)** | "archive project", "I'm done with project", "close project" | `Skill: pkb:project` with `archive <slug>` |
| 19 | **Topic Archive** | "archive wiki", "archive topic", "restore wiki", "restore topic", "list archived wikis", "show archived topics" | `Skill: pkb:archive` |

**Confidence routing:**

- **High confidence** — a single strong signal (URL present, question mark, exact keyword match like "compile" or "resume"). Route directly. Tell the user what you detected:
  > Detected: **ingest** (found URL). Routing to `/pkb:ingest`.

  Then invoke the Skill tool with the appropriate command and pass the user's text as arguments.

- **Low confidence** — ambiguous input that could match multiple intents, or no clear signal. Present the top 2-3 matching options as a numbered list:
  > Not sure what you're after. Pick one:
  >
  > 1. **Query** — ask the wiki what it knows
  > 2. **Research** — search the web and add new sources
  > 3. **Ingest** — add specific material you already have
  >
  > (1/2/3)

  Wait for their choice, then invoke the corresponding Skill.

- **No match** — the text doesn't match any pattern. Show wiki status (fall through to status section below) and list available subcommands.

**Key rules:**
- Never guess when ambiguous. A quick menu is faster than undoing the wrong action.
- Inventory and dataset signals outrank generic question or URL patterns. For
  example, "what should become inventory?" routes to inventory, and "track this
  URL as a candidate" routes to inventory rather than immediate ingest.
- Collect signals outrank plain inventory and research when the user asks to
  discover many objects before tracking them. For example, "collect and
  inventory all bitcoin memes" routes to collect, which writes a bounded
  catalog and then creates inventory only when it is the right layer.
- Project archive signals outrank topic archive when the word "project" is
  present. Dataset/source archive signals ("Wayback archive", "message
  archive", "dataset archive") route to ingest-collection, dataset, or
  inventory rather than lifecycle archive. Topic archive requires "wiki" or
  "topic", or an unambiguous restore/list archived-wikis request.
- Object words override Output's generic "create a"/"write a" signals:
  "create a project called X" routes to project new, "create an inventory
  record" to inventory, "create a dataset manifest" to dataset — Output wins
  only when the object is an artifact type (summary, report, slides, ...).
- For inventory/dataset routing, be opinionated about fit and show a small
  sample shape before asking the user to approve a larger pivot.
- Strip the signal words when passing args to the target command (e.g., "add https://example.com" → pass just the URL to ingest, not "add https://example.com").
- Include `--wiki` and `--local` flags from the original args when routing. Forward `--project` only to commands that define it (ingest, research, audit) — other targets cannot parse it.
- **No ambient project focus**: `--project <slug>` must be passed explicitly by the user. The focus-session mechanism was removed in the v0.2 projects simplification (see `skills/pkb-manager/references/projects.md` § "Focus"). If the user says "work on project X" without a clear sub-intent, treat it as a request to `show` the project — not as a focus state change.

---

### If $ARGUMENTS is empty (or just "status"/"stats"/"show") and a wiki exists

Show wiki status. Before reading any `_index.md`, stale-check it: count `.md` files in the directory vs rows in the index table. If mismatched, rebuild inline from file frontmatter first (see `references/indexing.md` Derived Index Protocol).

1. If at the hub level (HUB):
   - Read `HUB/_index.md` and `HUB/wikis.json`
   - For each active registered topic wiki, read its `_index.md` to get current stats
   - Count archived topics from registry entries with `status: archived` or
     paths under `topics/.archive/`
   - Show a summary table: wiki name, description, source count, article count
   - Show `Archived topics: N` and suggest `/pkb:archive list --archived` when
     N > 0
   - Show global log (last 5 entries)

2. If targeting a specific topic wiki (`--wiki <name>` or local):
   - Read its `_index.md` for statistics and recent changes
   - Read `config.md` for title and description
   - Count actual files for accuracy
   - Show: title, location, source/article/inventory/dataset/output counts, inbox pending, last compiled/checkup dates, last 5 recent changes

3. List available subcommands

---

### If no wiki exists and no "init" argument

The user is new or hasn't initialized a wiki yet. Instead of dumping a command list, walk them through getting started.

**Step 1: Welcome and orient.** Explain what llm-wiki does in one sentence, then ask what they want to research:

> **Welcome to llm-wiki** — a knowledge base that researches topics, ingests sources, and compiles them into articles you can query.
>
> To get started, what topic would you like to research? For example:
> - Quantum computing
> - Nutrition and supplements
> - Kubernetes deployment patterns
>
> Just tell me the topic, and I'll set everything up.

**Step 2: On user response,** derive a slug from their topic (lowercase, hyphens, max 40 chars) and run the full init protocol:
1. Create the hub if it doesn't exist (at the resolved HUB path from config, or ask the user where to create it if no config exists — never assume `~/llm-wiki-data/`)
2. Create the topic wiki at `HUB/topics/<slug>/` with the core directory structure
3. Register in wikis.json and update hub _index.md
4. Create config.md using the user's topic description

**Step 3: After init completes,** suggest the immediate next action based on what's most likely useful:

> **Wiki created at `HUB/topics/<slug>/`**
>
> What would you like to do first?
>
> 1. **Research** — I'll search the web and build your knowledge base automatically
>    → Just say: `/pkb:research "<your topic>" --wiki <slug>`
>
> 2. **Add a specific source** — paste a URL or file path
>    → Just say: `/pkb:ingest <url>`
>
> 3. **Import existing notes** — drop files into `HUB/topics/<slug>/inbox/`
>    → Then run: `/pkb:ingest --inbox`
>
> 4. **Import an existing wiki/repo** — ingest a Git docs repo or MediaWiki dump
>    → Just say: `/pkb:ingest-collection <url-or-path>`
>
> 5. **Collect examples or artifacts** — find many things, dedupe them, and save a provenance-rich catalog
>    → Just say: `/pkb:collect "<things to collect>"`

Do NOT show the full command reference, config options, or advanced flags during onboarding. Keep it to these starter options. The user can discover the rest via `/pkb` (status view) once they have a wiki.

**Permission hint (one-time):** If this is the first wiki being created, also append:

> **Tip:** Research sessions fetch many URLs. To skip approval prompts, add this to your project's `.claude/settings.local.json`:
> ```json
> "WebFetch", "WebSearch"
> ```
> in the `permissions.allow` array.

---

### If $ARGUMENTS starts with the word "config"

(Same rule as init: "how do I configure volatility?" is freeform text for the router, not a config request.)

Configure the wiki system.

#### `config hub-path <path>`

Set a custom hub location. Creates `~/.config/llm-wiki/config.json`.

**Steps:**

1. If `<path>` is provided:
   - Expand only a leading `~` in the path to validate it on this machine.
   - Check if the path exists as a directory. If not, offer to create it.
   - Write `~/.config/llm-wiki/config.json` (create `~/.config/llm-wiki/` if needed) with the user-facing portable path:
     ```json
     {
       "hub_path": "<path as the user typed it>"
     }
     ```
     Do not write `resolved_path` for normal shared hubs; it bakes in this machine's `/Users/<name>/...` path and can break iCloud-shared wiki folders on another Mac. Older configs that already have `resolved_path` remain readable as a fallback.
   - Suggest creating a symlink for maximum robustness:
     > For shell convenience, optionally run: `ln -s "<expanded path>" ~/llm-wiki-data`
     > This makes `~/llm-wiki-data/` always resolve immediately, even without reading config.
   - If a wiki already exists at the OLD hub location (previous config path or `~/llm-wiki-data/` fallback):
     - Ask: "Move existing wiki data from `<old>` to `<new>`? (y/n)"
     - If yes: move contents (`mv <old>/* <new>/`), update hub-owned `wikis.json` topic paths to relative `topics/<slug>` entries
     - If no: just update the config — user will move data manually
   - Report: "Hub path set to `<path>`. All wiki commands now use this location."

2. If no `<path>` provided (just `config hub-path`):
   - Read `~/.config/llm-wiki/config.json` if it exists
   - Report current hub path (prefer `hub_path`; mention `resolved_path` only if it is the only value or was used as a fallback)
   - Report: "Current hub path: `<path>`" or "No hub configured. Run `config hub-path <path>` to set one."

#### `config` (no subcommand)

Show all configuration:
- **Hub path**: current resolved path (and whether it's from config or default)
- **Config file**: `~/.config/llm-wiki/config.json` (exists / not found)
- **Topic wikis**: count from wikis.json
