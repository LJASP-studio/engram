# engram

A portable second brain for [Claude Code](https://code.claude.com). One Obsidian vault per machine, made of small linked notes that say where things live in the code, so Claude reads three short notes instead of crawling a repository.

An *engram* is the trace a memory leaves in the brain. The vault's structure (folders, hub, log, field names) is always English; the notes themselves can be written in English or Turkish.

## How it works

The system has two parts:

- **The engine** (this repository): a Claude Code plugin with four skills, templates and a lint script. The same engine is installed on every machine.
- **The vault**: a folder of Markdown notes inside your projects folder, one per machine. It stays on that machine in a local git repository with no remote. The engine never pushes anything anywhere.

```
projects/                 your projects folder (work or personal)
├── CLAUDE.md             + a short routing block written by /engram:setup
├── .claude/settings.json + read-deny rules for build output, lock files, .env
├── api/                  your projects, untouched
├── web/
└── brain/                the vault (local git only)
    ├── Home.md           hub: folder indexes, project hubs, log
    ├── Projects/         one hub per project, plus feature and module notes
    ├── Decisions/        2026-03-14 Sessions move to Redis.md
    ├── Releases/         api v2.1.0.md
    ├── Tech/             one note per tool, linked from every project that uses it
    ├── Concepts/         one note per theme shared by projects (security, privacy, determinism)
    ├── Daily/            one note per day, linking what changed that day
    ├── Views/            Obsidian Bases tables: decisions, releases, orphans
    └── Log.md            append-only change log
```

Every note carries a one-line `description`, a date taken from its source, the source itself and the code paths it describes:

```markdown
---
description: Documents and undo history live in one SQLite file per vault; saves are atomic.
date: 2026-01-10
source: inkwell/docs/decisions/0001-storage-sqlite.md
code: [inkwell/src/editor/]
tags: [decision]
---
```

The routing block tells Claude to grep the `description:` lines first (the `code:` paths come with them), and to read the hub and a folder index only when nothing matches or the question is broad; then to open at most three notes and jump to the code paths they name. Every extra step is a full model turn, so the shortest path to the right file is also the cheapest.

## Skills

| Skill | What it does |
|---|---|
| `/engram:setup [tr\|en]` | Sets up a vault in the current projects folder: note language (English or Turkish), hub, one index (MOC) per folder, routing block in `CLAUDE.md`, read-deny rules in `.claude/settings.json`, an offer to turn off Claude commit attribution, an Obsidian graph preset, Bases views, `.gitignore` and a local `git init`. Adopts an existing vault without moving anything. |
| `/engram:scan [project …] [--full]` | Scans the projects (git history, README, CLAUDE.md, docs, changelogs, manifests, existing Markdown and Obsidian vaults), one read-only subagent per project. Writes only notes with a source and a sourced date. Searches before writing, merges tool notes across projects, and rescans only what changed since the last scan. |
| `/engram:note [subject]` | After a task: writes or updates one note, adds it to its folder index and today's daily note, appends a log line and commits the vault locally. Claude can also call it on its own when work is done. |
| `/engram:check [--fix]` | Health check: notes without a description or date, broken links, orphans, notes missing from their index or from today's daily note, likely duplicates. Reports first, fixes on request. |

`setup`, `scan` and `check` run only when you type them, so their descriptions cost no context. Only `note` is listed to Claude every turn.

## Install

Requirements: Claude Code, git. Obsidian is optional (the vault is plain Markdown). The lint script needs a POSIX shell: built into macOS and Linux, and Git Bash on Windows; without it `/engram:check` does the same checks with Claude's own tools.

### macOS and Linux

```sh
claude plugin marketplace add muazfurkan/engram
claude plugin install engram@engram
```

Then, in the folder that holds your projects:

```sh
cd ~/code
claude
> /engram:setup en
> /engram:scan
```

### Windows

In PowerShell or Git Bash:

```powershell
claude plugin marketplace add muazfurkan/engram
claude plugin install engram@engram
cd D:\code
claude
```

Then `/engram:setup en` and `/engram:scan` inside Claude Code. Paths in notes always use forward slashes.

### Private repository access

The repository is private, so Claude Code clones it with your own git credentials. With an SSH key that works for github.com, nothing else is needed. Otherwise use HTTPS through the GitHub CLI:

```sh
gh auth login
gh auth setup-git
```

To force HTTPS, set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` (PowerShell: `$env:CLAUDE_CODE_PLUGIN_PREFER_HTTPS = "1"`). A `GITHUB_TOKEN` variable alone is not enough. Updates use the same credentials.

### If marketplaces are blocked

Some organisations block plugin marketplaces. Fallbacks, in order:

1. **Local marketplace.** `git clone` this repository, then `claude plugin marketplace add ./engram` and `claude plugin install engram@engram`.
2. **Per session.** Start Claude Code with `claude --plugin-dir path/to/engram`.
3. **Manual copy.** Copy `skills/setup`, `skills/scan`, `skills/note` and `skills/check` into `~/.claude/skills/` (Windows: `%USERPROFILE%\.claude\skills\`) and `reference/` into `~/.claude/reference/`, keeping both side by side so the skills find `../../reference/conventions.md`. The commands are then `/setup`, `/scan`, `/note` and `/check`; change `/engram:note` to `/note` in the routing block.

### Update

```sh
claude plugin marketplace update engram
claude plugin update engram@engram
```

Then `/reload-plugins` in a running session. Auto-update for third-party marketplaces is off until you turn it on in `/plugin`.

## Privacy

- Nothing leaves the machine. The vault is a local git repository; no skill adds a remote or pushes.
- Notes never hold secrets, tokens, `.env` values, customer data or personal data. `setup` adds read-deny rules for `.env` files, dependencies, build output and lock files.
- Notes from one machine never travel to another. A work vault stays on the work computer.

## Develop

```sh
sh tests/run.sh                          # lint script tests on a synthetic vault
sh skills/check/scripts/lint.sh examples/vault date Daily Home Log
claude plugin validate .                 # manifests
claude --plugin-dir .                    # try the skills without installing
```

`examples/projects/` holds two made-up projects and `examples/vault/` the vault the skills build from them. Bump `version` in `.claude-plugin/plugin.json` for every release.

## Layout

```
.claude-plugin/   plugin.json and marketplace.json (this repository is both)
reference/        conventions.md: note format, layout, retrieval order, writing rules
skills/setup/     setup skill and its templates (layout, hub, MOC, routing, deny rules, graph, Bases)
skills/scan/      scan skill and the brief each project's subagent gets
skills/note/      note skill
skills/check/     health check skill and scripts/lint.sh
examples/         synthetic sample projects and the vault built from them
tests/            run.sh
```
