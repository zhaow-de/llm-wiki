# Naming convention

The project deliberately uses three names; they are not interchangeable.
Pick by **what the token refers to**, not by where it appears.

## The three buckets

| Bucket       | Use it for                                                 | Examples |
|--------------|------------------------------------------------------------|----------|
| **`pkb`**      | The **plugin / command / tooling brand** — what you invoke. | `/pkb`, `/pkb-doctor`, `/pkb-ingest` (user aliases after `/pkb:install-commands`); `pkb:doctor` (plugin skill ref); the `pkb.py` CLI; plugin `name: pkb`; the `pkb-manager` skill |
| **`wiki`**     | The **concept** — the content structure the plugin builds. | "a wiki", "topic wiki", the `wiki/` content subdir, `wiki-structure.md`, `wikis.json`, "open the wiki as an Obsidian vault" |
| **`llm-wiki`** | The **project / repo / config / data** identity.           | the repo, the `llm-wiki` marketplace, `~/.config/llm-wiki/`, the hub dir `~/llm-wiki-data/`, the local dir `.llm-wiki-data/` |

## Decision rule

When a token could be more than one, ask: is it the **thing you invoke**
(brand → `pkb`), the **content artifact** (concept → `wiki`), or the
**repo / config / data on disk** (project → `llm-wiki`)?

Never write **"pkb knowledge base"** — `pkb` already expands to *personal
knowledge base*, so it doubles "kb". Say "the pkb plugin", or just "pkb".

## doctor vs checkup

The health-check command is **`/pkb-doctor`** (user alias) / **`/pkb:doctor`** (plugin skill ref) / **`pkb.py doctor`** (CLI).
The activity/report it produces is a **checkup** (`references/doctor.md` → `# Checkup Rules`, "checkup report", the `## [date] checkup` log entry).
