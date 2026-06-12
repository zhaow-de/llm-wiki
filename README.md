![Version](https://img.shields.io/badge/version-v0.0.1-blue)
![GitHub License](https://img.shields.io/github/license/zhaow-de/llm-wiki)

# llm-wiki - Personal Knowledge Base

An opinionated implementation of Karpathy's [LLM Wiki concept](https://x.com/karpathy/status/2039805659525644595) — a **Claude Code plugin** that turns Claude into the compiler and query engine for a personal, LLM-maintained knowledge base. Ready for using Obsidian as an optional content viewer.

This README has two audiences, and it is split to match:

**For wiki users** — install the plugin and drive it with `/pkb` commands to research, ingest, compile, and query a personal knowledge base. Installing means cloning this repo once; after that, nothing inside the repo needs to be read or changed.

**For plugin developers** — change the prompts, command specs, scripts, and tests that *are* this repo.

<!-- mdformat-toc start --slug=github --maxlevel=4 --minlevel=2 -->

- [Wiki Users](#wiki-users)
  - [What this is](#what-this-is)
  - [Three layers, one rule](#three-layers-one-rule)
  - [Install once](#install-once)
  - [The loop](#the-loop)
  - [Two dials](#two-dials)
  - [Keep it honest](#keep-it-honest)
  - [Read it anywhere](#read-it-anywhere)
  - [Reference](#reference)
    - [Commands](#commands)
    - [Examples](#examples)
    - [Research](#research)
    - [Query depths](#query-depths)
  - [Troubleshoot](#troubleshoot)
- [Plugin Developers](#plugin-developers)

<!-- mdformat-toc end -->

______________________________________________________________________

## Wiki Users<a name="wiki-users"></a>

### What this is<a name="what-this-is"></a>

Bookmarks rot. Notes go stale. "I read something about this once" is not knowledge.

`pkb` turns Claude Code into a compiler for the things worth knowing. Point it at the world — a question, a URL, a pile of PDFs — and it researches, reads, cross-checks, and writes the result into a wiki that stays queryable forever. The articles are never written by hand; Claude writes them. The job here is to ask.

The mental model is one sentence: **raw sources are the source code, Claude is the compiler, the wiki is the executable.** Everything else follows from that.

### Three layers, one rule<a name="three-layers-one-rule"></a>

```
raw/      ← sources, ingested once, never edited       (the source code)
wiki/     ← articles Claude synthesizes from raw/      (the executable)
output/   ← reports, slides, plans on request          (what ships)
```

The rule: **never hand-edit `wiki/`.** It is compiled — Claude rebuilds it from `raw/`. When an article is wrong, fix the *source* (ingest a better one, `/pkb-retract` a bad one) and recompile. Editing the compiled article is pointless: the next compile overwrites it.

Each **topic** is its own isolated wiki (crypto-quant, market-microstructure, defi…). Topics sit side by side under one **hub** but never bleed into each other — research stays scoped and context stays clean:

```
~/llm-wiki-data/               # Hub — registry only, no content
├── wikis.json                 # Registry of all topic wikis
├── _index.md                  # Lists topic wikis with stats
├── log.md                     # Global activity log
└── topics/
    └── <topic>/               # One isolated wiki per topic
        ├── raw/               # Immutable sources
        ├── wiki/              # Compiled, cross-linked articles
        ├── output/            # Generated artifacts + projects
        ├── inventory/         # Lazy: durable tracking records
        ├── datasets/          # Lazy: manifests for large/external data
        ├── _index.md
        ├── config.md
        └── log.md
```

`_index.md` files are a derived cache rebuilt from frontmatter — also never hand-edited. For the full design — components, flows, and the rationale behind them — see [docs/llm-agent-architecture.md](docs/llm-agent-architecture.md).

### Install once<a name="install-once"></a>

`pkb` installs into Claude Code from a local checkout of this repo. Cloning it is a one-time install step — afterward the repo never needs opening again:

```bash
git clone https://github.com/zhaow-de/llm-wiki.git
claude plugin marketplace add /absolute/path/to/llm-wiki
claude plugin install pkb@llm-wiki

# restart Claude Code or run /reload-plugins in Claude Code
```

Then, in Claude Code, run once to register the `/pkb-*` slash commands:

```
/pkb:install-commands
```

After this, invoke wiki commands as `/pkb`, `/pkb-research`, `/pkb-ingest`, etc. Re-run `/pkb-install-commands` after plugin updates to sync any new or removed commands.

Confirm it loaded with `/pkb status`. Claude Desktop picks up the same plugin once Claude Code has installed it.

The wiki lives at `~/llm-wiki-data/` by default; change the hub path with `/pkb config hub-path "<new-path>"`. To move to a newer version later, run `git -C /path/to/llm-wiki pull` then `claude plugin update pkb@llm-wiki` (restart or `/reload-plugins`).

### The loop<a name="the-loop"></a>

Day-to-day work is one of three verbs. These three are the whole language:

| Verb         | Command                                                         | What it does                                                                              |
| ------------ | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Research** | `/pkb-research "funding rate arbitrage" --new-topic`            | Fans out parallel agents, ingests sources, compiles articles — hands back a finished wiki |
| **Capture**  | `/pkb-ingest <url>` · drop files in `inbox/` · `/pkb add <url>` | Pulls in a source spotted by hand, rather than one the agents found                       |
| **Ask**      | `/pkb-query "how do funding rates drive perp basis?"`           | Answers from the wiki, with citations back to the sources                                 |

The headline move — start a topic and walk away:

```
/pkb-research "perpetual futures market making" --new-topic --min-time 2h
```

It researches in rounds for two hours, drilling into every gap the previous round exposed. What waits afterward is a compiled wiki — not a tab graveyard.

### Two dials<a name="two-dials"></a>

Most flags do not matter day to day. Two do:

- **Breadth** — how hard to dig. Default is 5 agents; `--deep` is 8; `--retardmax` is 10, no planning, widest net.
- **`--mode`** — *what kind* of question. The default is open-ended exploration. `--mode thesis` flips it into a prosecutor: feed it a claim and it hunts evidence **for and against**, then returns a verdict instead of a vibe.

Full tables for both are under [Research](#research) below.

### Keep it honest<a name="keep-it-honest"></a>

A knowledge base that cannot be trusted is worse than none, so `pkb` defends its own credibility:

- `/pkb-refresh --due` — re-verify articles that have gone stale
- `/pkb-audit` — trace a claim back through the wiki to its sources, and re-research when they look shaky
- `/pkb-doctor` — structural health check (`--fix` cleans the obvious issues; see [Troubleshoot](#troubleshoot))

### Read it anywhere<a name="read-it-anywhere"></a>

The wiki is plain markdown with dual links, so it is never trapped in one tool:

```
open ~/llm-wiki-data/        # the whole knowledge base as one Obsidian vault
```

Obsidian draws the graph; Claude Code, GitHub, and any plain editor read the same files. A `--local` wiki (`.llm-wiki-data/`) opens as its own self-contained vault. Because one vault spans all topics, wikilink names can collide across topics — disambiguate with paths or aliases when needed. Claude is the compiler; Obsidian is just a window onto the result.

### Reference<a name="reference"></a>

The full surface area follows. Most work runs for weeks on `research`, `query`, and `ingest` alone.

#### Commands<a name="commands"></a>

| Command                                                                                                            | Description                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `/pkb <natural language>`                                                                                          | Fuzzy intent router — state the goal in natural language and it routes to the right subcommand                            |
| `/pkb`                                                                                                             | Show wiki status, stats, and list all topic wikis                                                                         |
| `/pkb init <name>`                                                                                                 | Create a topic wiki at `~/llm-wiki-data/topics/<name>/`                                                                   |
| `/pkb init <name> --local`                                                                                         | Create a project-local wiki at `.llm-wiki-data/`                                                                          |
| `/pkb config`                                                                                                      | Show all configuration (hub path, config file, topic wiki count)                                                          |
| `/pkb config hub-path [<path>]`                                                                                    | Set the hub location (writes `~/.config/llm-wiki/config.json`), or show the current one                                   |
| `/pkb-ingest <source>`                                                                                             | Ingest a URL, file path, PDF, or quoted text                                                                              |
| `/pkb-ingest --inbox [--keep]`                                                                                     | Process all files in the topic wiki's inbox/ (`--keep` moves originals to `.processed/` instead of deleting)              |
| `/pkb-ingest … --type <t> --title "T" --auto-classify --new-topic <n> --project <slug>`                            | Force the source type, override the title, auto-route to the best wiki, create a new topic, or tag a project              |
| `/pkb-ingest-collection <source>`                                                                                  | Bulk-ingest Git doc repos, BIP-style proposal sets, MediaWiki dumps/API sites, message archives, or Wayback CDX snapshots |
| `/pkb-ingest-collection <source> --adapter git\|mediawiki-dump\|mediawiki-api\|csv-messages\|wayback-cdx`          | Force a collection adapter                                                                                                |
| `/pkb-ingest-collection <source> --limit <N> --dry-run`                                                            | Preview or cap a large collection import                                                                                  |
| `/pkb-ingest-collection … --new-topic <n> --namespace <id> --include/--exclude <pat> --from/--to <date> --compile` | Create the target topic, filter MediaWiki namespaces or paths, bound Wayback date ranges, compile right after import      |
| `/pkb-collect "<things>"`                                                                                          | Find, dedupe, and catalog artifacts, examples, resources, media, memes, tools, entities, or source candidates             |
| `/pkb-collect "<things>" --scale tiny\|small\|medium\|large\|huge`                                                 | Control write behavior by operational scale, not just row count                                                           |
| `/pkb-collect "<things>" --media archive\|thumbnail\|reference`                                                    | Download/cache bounded originals by default; use thumbnail for previews or reference to opt out                           |
| `/pkb-collect "<things>" --inventory records`                                                                      | Create per-item inventory records when the collected set is small enough to stay useful                                   |
| `/pkb-collect "<things>" --inventory corpus`                                                                       | Track a large, unstable, or media-heavy collection as one corpus record linked to the catalog output                      |
| `/pkb-collect "<things>" --type <kind> --limit <N> --ingest-sources --dry-run`                                     | Force the collected kind, cap the catalog, ingest strong supporting pages as raw sources, or preview without writing      |
| `/pkb-inventory list`                                                                                              | List durable tracking records as compact chat-friendly tables or bullets                                                  |
| `/pkb-inventory list --view actions`                                                                               | Show current inventory next actions without dumping full records                                                          |
| `/pkb-inventory add <kind> "title" [--priority p0-p4] [--source <path-or-url>]`                                    | Add an inventory record after checking that inventory is the right layer                                                  |
| `/pkb-inventory show <slug>` / `update <path>`                                                                     | Show one record in full, or update its status/priority/next action                                                        |
| `/pkb-inventory list --kind/--status/--priority --view summary\|items\|records\|sources --format table\|list`      | Filter records and pick the view/format of the listing                                                                    |
| `/pkb-inventory save-view "name"`                                                                                  | Save a derived reusable table/list under `inventory/views/`                                                               |
| `/pkb-inventory scan-outputs --dry-run`                                                                            | Find old queue/backlog outputs and preview sample records before migration                                                |
| `/pkb-inventory migrate-output <path> --apply`                                                                     | Additively create inventory records from a legacy output; never moves or deletes the output                               |
| `/pkb-dataset list`                                                                                                | List dataset manifests as compact chat-friendly tables or bullets                                                         |
| `/pkb-dataset list --view schema`                                                                                  | Show schema/readiness state without opening samples or data                                                               |
| `/pkb-dataset add "title" --location <path-or-url>`                                                                | Add a dataset manifest without copying data into the wiki                                                                 |
| `/pkb-dataset show <slug>` / `sample <slug> [--limit N]`                                                           | Show one manifest in full, or capture a bounded sample note                                                               |
| `/pkb-dataset list --status/--storage --view summary\|manifests\|locations --format table\|list`                   | Filter manifests and pick the view/format of the listing                                                                  |
| `/pkb-dataset profile <slug> --dry-run`                                                                            | Preview lightweight profiling of size, format, headers, or schema observations                                            |
| `/pkb-dataset scan-outputs --dry-run`                                                                              | Find old output artifacts that describe datasets and preview manifest candidates before migration                         |
| `/pkb-dataset migrate-output <path> --apply`                                                                       | Additively create dataset manifests from a legacy output; never moves or copies the underlying data                       |
| `/pkb-archive list [--archived]`                                                                                   | List active topic wikis and optionally archived topic wikis                                                               |
| `/pkb-archive topic <slug> --reason "why"`                                                                         | Move a topic wiki to `topics/.archive/<slug>` and hide it from default context                                            |
| `/pkb-archive restore <slug>`                                                                                      | Restore an archived topic wiki to active status                                                                           |
| `/pkb-archive peek <query>`                                                                                        | Search archived topic indexes without reading archived articles                                                           |
| `/pkb-compile`                                                                                                     | Compile new sources into wiki articles                                                                                    |
| `/pkb-compile --full`                                                                                              | Recompile everything from scratch                                                                                         |
| `/pkb-compile --source <path>` / `--topic <name>`                                                                  | Compile one specific source, or create/update one specific topic article                                                  |
| `/pkb-retract <source-path> --reason "why"`                                                                        | Remove a source and clean its full blast radius (`--dry-run` to preview, `--recompile` to resynthesize affected articles) |
| `/pkb-refresh [<article-path>]`                                                                                    | Re-verify an article's facts against its sources and update its `verified` date                                           |
| `/pkb-refresh --due [--wiki <name\|all>]`                                                                          | List articles below the freshness threshold and refresh the selected ones                                                 |
| `/pkb-project new <slug> "goal"`                                                                                   | Create `output/projects/<slug>/` with its required WHY.md                                                                 |
| `/pkb-project list [--archived]` / `show <slug>`                                                                   | List project folders, or show one project's contents                                                                      |
| `/pkb-project add <slug> <path>`                                                                                   | Move a loose output into a project folder                                                                                 |
| `/pkb-project archive <slug>`                                                                                      | Move a finished project to `output/projects/.archive/`                                                                    |
| `/pkb-query <question>`                                                                                            | Q&A against the wiki (standard depth)                                                                                     |
| `/pkb-query <question> --quick`                                                                                    | Fast answer from indexes only                                                                                             |
| `/pkb-query <question> --deep`                                                                                     | Thorough — reads everything, checks raw + sibling wikis                                                                   |
| `/pkb-query <question> --raw`                                                                                      | Also search raw sources, not just compiled articles (implied by `--deep`)                                                 |
| `/pkb-query <question> --include-archived`                                                                         | Explicitly search/read archived material, with archived citations labeled                                                 |
| `/pkb-query <terms> --list [--tag <tag>] [--category <cat>]`                                                       | Find content by keyword, tag, or category (replaces old `/pkb:search`)                                                    |
| `/pkb-query --resume`                                                                                              | Reload context after a session break — recent activity, stats, last-updated articles                                      |
| `/pkb-plan <goal>`                                                                                                 | Generate wiki-grounded implementation plan (interview → gap research → phased plan)                                       |
| `/pkb-plan <goal> --quick`                                                                                         | Plan from wiki content only — skip interview and gap research                                                             |
| `/pkb-plan <goal> --no-interview` / `--no-research`                                                                | Skip only the interview stage, or only the gap-research stage                                                             |
| `/pkb-plan <goal> --format rfc\|adr\|spec`                                                                         | Output as RFC, ADR, or tech spec instead of roadmap                                                                       |
| `/pkb-research <topic>`                                                                                            | 5 parallel agents: academic, technical, applied, news, contrarian                                                         |
| `/pkb-research <topic> --new-topic`                                                                                | Create a topic wiki and start researching — works from any directory                                                      |
| `/pkb-research <topic> --min-time 1h`                                                                              | Keep researching in rounds until time budget is spent                                                                     |
| `/pkb-research <topic> --plan`                                                                                     | Decompose into 3-5 parallel paths, confirm, then dispatch all at once                                                     |
| `/pkb-research <topic> --deep`                                                                                     | 8 agents: adds historical, adjacent, data/stats                                                                           |
| `/pkb-research <topic> --retardmax`                                                                                | 10 agents: skip planning, max speed, ingest aggressively                                                                  |
| `/pkb-research <topic> --project <slug>`                                                                           | Save the research playbook into `output/projects/<slug>/` and tag compiled articles with the project                      |
| `/pkb-research <claim> --mode thesis`                                                                              | Thesis-driven research: evidence for + against → verdict                                                                  |
| `/pkb-research <claim> --mode thesis --min-time 1h`                                                                | Multi-round thesis investigation with anti-confirmation-bias                                                              |
| `/pkb-doctor`                                                                                                      | Run health checks on the wiki                                                                                             |
| `/pkb-doctor --fix`                                                                                                | Auto-fix structural issues                                                                                                |
| `/pkb-doctor --deep`                                                                                               | Web-verify facts and suggest improvements                                                                                 |
| `/pkb-doctor --archived-only`                                                                                      | Structural checks for archived topic wikis only                                                                           |
| `/pkb-audit`                                                                                                       | Umbrella trust audit: wiki, outputs, provenance, and fresh research when needed                                           |
| `/pkb-audit --artifact <path>`                                                                                     | Audit one article or output artifact and follow its evidence chain                                                        |
| `/pkb-audit --project <slug>`                                                                                      | Audit one project's outputs and upstream wiki state                                                                       |
| `/pkb-audit scan --wiki-only\|--outputs-only --quick --fresh`                                                      | Scope the audit pass; `--quick` stays local-only, `--fresh` ignores cached librarian results                              |
| `/pkb-audit report`                                                                                                | Display the latest umbrella audit report                                                                                  |
| `/pkb-librarian`                                                                                                   | Focused wiki maintenance: staleness and quality scan for the `wiki/` layer                                                |
| `/pkb-librarian --article <path>`                                                                                  | Scan a single article                                                                                                     |
| `/pkb-librarian scan --resume --passes <list> [--wiki <name\|all>]`                                                | Resume an interrupted scan, choose passes (default `staleness,quality`), or scan every active wiki                        |
| `/pkb-librarian fix <id>`                                                                                          | Reserved — not yet implemented; the command currently replies that fix operations are unavailable                         |
| `/pkb-librarian report`                                                                                            | Display the latest librarian scan report                                                                                  |
| `/pkb-output <type>`                                                                                               | Generate: summary, report, study-guide, slides, timeline, glossary, comparison                                            |
| `/pkb-output <type> --sources <paths>`                                                                             | Generate from specific wiki articles only                                                                                 |
| `/pkb-output <type> --retardmax`                                                                                   | Ship it now — rough but comprehensive, iterate later                                                                      |
| `/pkb-ll`                                                                                                          | Extract lessons learned from the current session into the wiki                                                            |
| `/pkb-ll --dry-run`                                                                                                | Preview extracted lessons without writing                                                                                 |
| `/pkb-ll --rules`                                                                                                  | Also suggest CLAUDE.md rule additions                                                                                     |
| `/pkb-assess <path>`                                                                                               | Assess a repo against wiki research + market. Gap analysis.                                                               |
| `/pkb-assess <path> --retardmax`                                                                                   | Wide net — adds adjacent fields and failure analysis                                                                      |

All commands accept `--wiki <name>` to target a specific topic wiki and `--local` to target the project wiki — except `/pkb-archive`, which operates at the hub level (only its `peek` subcommand takes `--wiki`, and project-local `.llm-wiki-data/` directories cannot be archived). Archived topic wikis are skipped by default; commands that support `--include-archived` require that explicit flag before reading or writing archived material. Commands that generate content (`query`, `output`, `plan`) also accept `--with <wiki>` to load supplementary wikis as cross-wiki context — e.g., `--with article-writing` applies writing craft knowledge when generating output from a domain wiki.

`/pkb-librarian` is the focused wiki-maintenance tool. `/pkb-audit` is broader and may perform fresh research to decide whether the current knowledge or generated outputs are still trustworthy.

#### Examples<a name="examples"></a>

```shell
# ── Daily — research, capture, ask ──────────────────────────────

# Create wiki + research in one shot
/pkb-research "funding rate arbitrage" --new-topic

# Add more research to an existing wiki
/pkb-research "perp basis" --wiki crypto-quant

# 8 agents, keep going for 2 hours
/pkb-research "market making" --deep --min-time 2h

# 10 agents, max speed, ingest everything
/pkb-research "statistical arbitrage" --retardmax

# Question → decompose → playbook
/pkb-research "What makes a crypto market-making strategy profitable?" --new-topic

# Thesis: evidence for + against → verdict
/pkb-research "funding-rate carry on perps delivers positive risk-adjusted returns" --mode thesis

# Deep thesis investigation
/pkb-research "high basis predicts negative forward returns" --mode thesis --min-time 1h

# Manually ingest a source
/pkb-ingest https://example.com/strategy-writeup

# Fuzzy router detects URL → ingest
/pkb add https://example.com/strategy-writeup

# Process files dropped in inbox/
/pkb-ingest --inbox

# Bulk import spec repos
/pkb-ingest-collection https://github.com/bitcoin/bips --wiki bitcoin

# Import MediaWiki dumps
/pkb-ingest-collection https://dump.bitcoin.it/dump_20260429_en.xml.bz2 --wiki bitcoin

# Split record/message archives
/pkb-ingest-collection trades.csv --adapter csv-messages --wiki crypto-quant

# Import archived snapshots
/pkb-ingest-collection "https://example.com/*" --adapter wayback-cdx --from 20100101 --to 20200101

# Find, dedupe, download media, catalog
/pkb-collect "perp DEX analytics dashboards" --wiki crypto-quant

# Catalog media without binary downloads
/pkb-collect "bitcoin memes" --scale medium --media reference --inventory corpus

# Ask the wiki
/pkb-query "How do funding rates drive perp basis?"

# Fuzzy router detects question → query
/pkb what do we know about MEV sandwich attacks?

# Deep cross-referenced answer
/pkb-query "compare funding-carry and cash-and-carry basis trades" --deep

# Where the last session left off
/pkb-query --resume

# ── Maintenance — compile, verify, organize, produce ────────────

# Compile any unprocessed sources
/pkb-compile

# Re-verify articles below the freshness threshold
/pkb-refresh --due

# Remove a source + clean its blast radius
/pkb-retract raw/articles/2026-bad-backtest.md --reason "Lookahead bias found"

# Preserve a topic but hide it from normal context
/pkb-archive topic old-strategy --reason "No longer traded"

# Show active and archived topic wikis
/pkb-archive list --archived

# Bring an archived topic back
/pkb-archive restore old-strategy

# Track source queues and next actions
/pkb-inventory add ingest-candidate "Deribit Insights blog" --wiki crypto-quant

# Track accounts, feeds, hosts, or assets
/pkb-inventory add item "Kaiko market-data subscription" --wiki crypto-quant

# Compact chat table of current inventory next actions
/pkb-inventory list --view actions --limit 10

# Preview queues/backlogs before any inventory pivot
/pkb-inventory scan-outputs --dry-run

# Index data that stays external
/pkb-dataset add "Binance 1m OHLCV 2017-2025" --location s3://md-bucket/binance-ohlcv --wiki crypto-quant

# Compact chat table of dataset schema/readiness state
/pkb-dataset list --view schema --limit 10

# Find legacy data reports that could become dataset manifests
/pkb-dataset scan-outputs --dry-run

# Truth-seeking audit across outputs + wiki + fresh research
/pkb-audit --project funding-carry-backtest

# Group outputs into a project folder
/pkb-project new funding-carry-backtest "Ship the funding-carry backtest"

# Generate a report
/pkb-output report --topic funding-rates

# Ship a rough slide deck NOW
/pkb-output slides --retardmax

# Gap analysis: repo vs wiki vs market
/pkb-assess /path/to/my-strategy --wiki crypto-quant
```

#### Research<a name="research"></a>

`/pkb-research` casts a fan-out of parallel agents and compiles what they find into the wiki. A run is shaped by three independent choices: how wide it casts (**breadth**), what kind of research it does (**`--mode`**), and **modifiers**.

**Breadth** — how many parallel agents:

| Breadth   | Flag          | Agents | Style                                                                                                      |
| --------- | ------------- | ------ | ---------------------------------------------------------------------------------------------------------- |
| Standard  | *(default)*   | 5      | Academic, technical, applied, news, contrarian                                                             |
| Deep      | `--deep`      | 8      | Adds historical, adjacent fields, data/stats                                                               |
| Retardmax | `--retardmax` | 10     | Adds rabbit-hole agents. Skip planning, cast widest net, ingest aggressively, compile fast. Checkup later. |

**`--mode`** — what kind of research:

| Mode                   | Flag            | What it does                                                                                            |
| ---------------------- | --------------- | ------------------------------------------------------------------------------------------------------- |
| Open-ended *(default)* | *(none)*        | Explore a topic or answer a question — auto-detects which (see below)                                   |
| Thesis                 | `--mode thesis` | Treat the input as a claim to evaluate: balanced supporting/opposing agents, evidence tables, a verdict |

In **open-ended** mode, `/pkb-research` auto-detects whether the input is a topic or a question:

| Input                                               | Detected as | Behavior                                                                                                    |
| --------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------- |
| `"funding rate arbitrage"`                          | Topic       | Standard research — explore the field                                                                       |
| `"What makes a market-making strategy profitable?"` | Question    | Decompose into sub-questions → one agent per sub-question → synthesize → generate playbook → suggest theses |

Question input produces a **playbook** (an actionable output artifact) and suggests **testable theses** derived from the findings.

In **thesis** mode the input is a claim, and the run:

1. Decomposes the thesis into key variables, testable predictions, and falsification criteria
1. Launches parallel agents, each using the thesis as a FILTER — irrelevant sources get skipped, which prevents bloat
1. Splits agents into **supporting**, **opposing**, **mechanistic**, **meta/review**, and **adjacent** — balanced by design
1. Compiles evidence into wiki articles plus a thesis file with evidence tables
1. Delivers a **verdict**: supported / partially supported / contradicted / insufficient evidence / mixed

With `--min-time`, Round 2 automatically focuses on the WEAKER side of the evidence (anti-confirmation-bias): if Round 1 found mostly supporting evidence, Round 2 hunts for counter-evidence. The thesis doubles as the bloat filter — sources unrelated to the claim's variables don't get ingested, so a higher skip rate means tighter focus.

**Modifiers** (combine with any breadth or mode):

| Flag                    | What it does                                                                                                                                 |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `--new-topic`           | Create a topic wiki from the research topic and start immediately. Works from any directory.                                                 |
| `--plan`                | Decompose into 3-5 parallel research paths, confirm, then dispatch all paths simultaneously. Parallel ingest, sequential compile.            |
| `--min-time <duration>` | Keep running research rounds until the time budget is spent (`30m`, `1h`, `2h`, `4h`). Each round drills into gaps the previous round found. |
| `--sources <N>`         | Sources per round (default: 5, retardmax: 15)                                                                                                |
| `--project <slug>`      | Save the research playbook into `output/projects/<slug>/` and tag compiled articles with the project                                         |

```
# Full combo — new topic, 2 hours of deep open-ended research, from anywhere
/pkb-research "perpetual futures market making" --new-topic --deep --min-time 2h

# A claim, investigated over an hour with anti-confirmation-bias rounds
/pkb-research "funding-rate carry on perps delivers positive risk-adjusted returns" --mode thesis --min-time 1h
```

Retardmax breadth is inspired by [Elisha Long's retardmaxxing philosophy](https://www.retardmaxx.com/) — act first, think later. The antidote to analysis paralysis. It works for both `/pkb-research` and `/pkb-output`.

#### Query depths<a name="query-depths"></a>

| Depth    | Flag        | What it does                                                                                                        |
| -------- | ----------- | ------------------------------------------------------------------------------------------------------------------- |
| Quick    | `--quick`   | Reads indexes only. Fastest. For simple lookups.                                                                    |
| Standard | *(default)* | Reads relevant articles + full-text search. For most questions.                                                     |
| Deep     | `--deep`    | Reads everything active, searches raw sources, peeks sibling wikis, and surfaces archived index matches separately. |
| List     | `--list`    | Returns ranked article list instead of synthesized answer. Supports `--tag` and `--category` filters.               |

Archived topics are excluded from quick, standard, and list results unless `--include-archived` is passed. Deep mode may show archived index hits, but it does not cite archived material as active evidence without explicit inclusion.

### Troubleshoot<a name="troubleshoot"></a>

If `/pkb` commands don't appear after installing or updating, restart Claude Code or run `/reload-plugins`.

Check the wiki's health with the agentic doctor:

```
/pkb-doctor          # Run health checks on the wiki
/pkb-doctor --fix    # Auto-fix structural issues
/pkb-doctor --deep   # Web-verify facts and suggest improvements
```

For a deterministic, no-LLM checkup — or to run checks straight from the cloned checkout — use the bundled `pkb.py` CLI. It covers the structural checks that don't need an agent (the agentic `/pkb-doctor` remains the full editorial protocol) plus the structural archive operations:

```bash
./pkb.py doctor /path/to/llm-wiki-data
./pkb.py doctor --fix /path/to/llm-wiki-data
./pkb.py doctor --wiki <name> [--hub /path/to/hub] [--include-archived] [--json]   # hub-registry resolution, machine-readable report
./pkb.py doctor --local                                                            # checkup .llm-wiki-data/ in the current directory
./pkb.py archive --hub /path/to/hub topic old-strategy --reason "No longer traded"
./pkb.py archive --hub /path/to/hub list --archived [--json]
./pkb.py archive --hub /path/to/hub restore old-strategy
```

______________________________________________________________________

## Plugin Developers<a name="plugin-developers"></a>

This repo *is* the plugin. Anyone who only wants to use the wiki can stop at the section above.

- **Start at [`CLAUDE.md`](CLAUDE.md)** — the dev contract: structure, tooling, testing, release, and conventions.
- **Design rationale** lives in [`docs/llm-agent-architecture.md`](docs/llm-agent-architecture.md) — read it before adding or reshaping a feature.
- **Source of truth** is `plugin/`: the `pkb-manager` skill (`SKILL.md` + `references/*.md`) and the `/pkb` command specs (`commands/*.md`). Editing a reference *is* editing runtime behavior — there are no generated mirrors.

Development cycle:

```bash

# one time
brew install uv
uv run pre-commit install            # one-time commit-hook gate

# before starting the development
uv sync                              # locked dev toolchain (pre-commit, etc.)

# ------
# regular software development and maintainence activities
# ------

# run the tests
./tests/test-plugin-validate.sh      # plugin manifest + frontmatter
./tests/test-structure.sh            # wiki fixture validation
./tests/test-local-cli-doctor.sh     # deterministic CLI checks

# ------
# regular software releasing activities
# ------
```

Cut a release with the `/release` skill (commitizen-driven, `develop → main`). Branch, PR, and commit conventions live in `.claude/rules/`.
