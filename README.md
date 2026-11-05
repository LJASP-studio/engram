# engram

A portable second brain for [Claude Code](https://code.claude.com). One Obsidian vault per machine, made of small linked notes that say where things live in the code, so Claude reads three short notes instead of crawling a repository.

An *engram* is the trace a memory leaves in the brain. The vault's structure (folders, hub, log, field names) is always English; the notes themselves can be written in English or Turkish.

## How it works

The system has two parts:

- **The engine** (this repository): a Claude Code plugin with four skills, templates, two shell helpers and an optional live graph for Obsidian. The same engine is installed on every machine.
- **The vault**: a folder of Markdown notes inside your projects folder, one per machine. It stays on that machine in a local git repository with no remote. The engine never pushes anything anywhere.

```
projects/                 your projects folder (work or personal)
├── CLAUDE.md             + a short routing block written by /engram:setup
├── .claude/settings.json + read-deny rules: build output, lock files, secrets, folders set to none
├── api/                  your projects, untouched
├── web/
└── brain/                the vault (local git only)
    ├── Home.md           hub: folder indexes, project hubs, log
    ├── Projects/         one hub and one status note per project, plus feature and module notes
    ├── Decisions/        2026-03-14 Sessions move to Redis.md
    ├── Releases/         api v2.1.0.md
    ├── Tech/             one note per tool, linked from every project that uses it
    ├── Concepts/         one note per theme shared by projects (security, privacy, determinism)
    ├── Daily/            one note per day, linking what changed that day
    ├── Proposals/        changes engram wants to make to notes you edited, waiting for you
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
| `/engram:setup [tr\|en]` | Sets up a vault in the current projects folder: note language (English or Turkish), hub, one index (MOC) per folder, a privacy level per project folder, routing block in `CLAUDE.md`, read-deny rules in `.claude/settings.json`, an offer to turn off Claude commit attribution, an Obsidian graph preset, Bases views, `.gitignore` and a local `git init`. Adopts an existing vault without moving anything. `/engram:setup privacy` changes the privacy levels later. |
| `/engram:scan [project …] [--full]` | Scans the projects (git history, README, CLAUDE.md, docs, changelogs, manifests, existing Markdown and Obsidian vaults), one read-only subagent per project, within each project's privacy level. Shows a plan (new notes, updates, proposals) and writes nothing before your OK. Writes only notes with a source and a sourced date, creates a status note per project from sourced material, rescans only what changed since the last scan, and never overwrites your own edits. |
| `/engram:note [subject]` | After a task: writes or updates one note, adds the session's outcome to the project's status note, adds both to their index and today's daily note, appends a log line and commits the vault locally. Claude can also call it on its own when work is done. |
| `/engram:check [--fix]` | Health check: missing description, date or source, broken links, orphans, notes missing from their index or today's daily note, code paths that no longer exist, notes whose code changed since the last scan, decisions inferred from commits, pending proposals, privacy rules out of sync, likely duplicates. Reports first, fixes on request. |

`setup`, `scan` and `check` run only when you type them, so their descriptions cost no context. Only `note` is listed to Claude every turn.

## What keeps the vault honest

- **Sources.** Notes in the projects, decisions, releases, tech and concepts folders, and any note with code paths, name their source: a file, a commit, a tag, a URL, or the session in which you said it. `/engram:check` reports `MISSING_SOURCE`.
- **Code paths exist.** Every `code:` path is checked against the projects folder (`CODE_PATH_MISSING`); a `projectsRoot` that points nowhere is an error too (`PROJECTS_ROOT_MISSING`), so a wrong setting cannot pass as clean.
- **Staleness is visible.** When files under a note's code paths change in commits after the project's last scan and after the note was last written, the check reports `STALE`. Re-scan the project, or review the note and add the commit you checked to its source.
- **Inferred decisions are marked.** A decision whose only evidence is commit messages carries `confidence: inferred` until you confirm it (`confidence: confirmed`).
- **Status notes.** Each project has `<Project> status.md` with four sections: now, next, open questions, tried and did not work. `scan` fills it only from a status file or an `Unreleased` changelog section and leaves the rest empty; `note` adds a dated line after each task.

## Your edits are safe

engram tells your text from its own with git, so notes need no markers. Every engram commit starts with `docs:` or `chore:`, and before any skill writes, it commits whatever you changed in the meantime as `chore: snapshot manual edits`. A note with uncommitted changes, or with a snapshot commit or a commit of your own anywhere in its history, holds your edits from then on.

On such a note engram only adds: an index line, a link, a source or code path, a status line. A change that would reword or remove anything is written to `Proposals/<Title>.proposal.md` with the reason and the full proposed note, and logged. You decide whether to apply it (engram merges it, keeping every line you wrote) or drop it. `skills/scan/scripts/edited.sh <vault>` lists the notes that hold your edits.

If you commit to the vault yourself, use any message that does not start with `docs:` or `chore:`, or simply leave the changes for engram to snapshot.

The vault may also be reorganised as it grows: notes can be renamed, moved or merged, each as its own commit with every link updated in the same step and a clean check afterwards. A merge that removes a file asks first.

## Privacy

What an LLM may read is decided on each machine, the first time `/engram:setup` runs there:

| Level | What engram does with the folder |
|---|---|
| `full` | Reads documents, code and git history. |
| `structure` | Uses folder and file names only: no file contents, no commit messages. Its notes are marked `visibility: internal`. |
| `none` | Skips it entirely: nothing listed, read or written about it. |

Some file patterns are never read in any project: `.env` files, private keys, certificates, keystores, credential files. The levels and patterns live in the vault's `.engram.json` under `privacy`. Setup also writes them as `Read` deny rules into the projects folder's `.claude/settings.json` (`Read(/<folder>/**)` for every `none` folder, `Read(./**/<pattern>)` for every pattern), so Claude Code refuses them to its file tools in every session started in that folder, not only during a scan. A deny rule also stops Claude from editing files there from that folder. `/engram:setup privacy` changes both whenever you want, for example to open a `none` folder again; `/engram:check` warns when they disagree or when notes exist for a `none` folder. A folder that appears later is asked about before it is scanned.

Limits: deny rules cover Claude Code's file tools and the shell file commands it recognises, not every program a shell command may start, and a session started inside a project folder reads that folder's settings instead. For OS-level enforcement, use Claude Code's sandbox.

Before you run engram on a work computer:

- **Check your employer's policy** on sending company code and documents to an LLM service. Everything a skill reads is sent to the model. Use `structure` or `none` for anything the policy does not cover.
- **Never keep a vault in iCloud Drive on Windows.** Obsidian's own help warns that iCloud Drive on Windows may duplicate or corrupt files. Use a plain local folder; the vault is already versioned by git.
- **Pause file sync during bulk writes.** OneDrive, Dropbox, Google Drive and iCloud can conflict with a scan that writes hundreds of files at once. Pause sync before `/engram:scan` or a large `/engram:check --fix`, and resume it afterwards.
- Nothing leaves the machine through engram itself. The vault is a local git repository; no skill adds a remote or pushes. Notes never hold secrets, tokens, `.env` values, customer data or personal data. Notes from one machine never travel to another; a work vault stays on the work computer.

## Live graph

An optional Obsidian plugin that shows Claude's work on the vault in the graph view, for demos and for seeing what Claude actually opened. A note Claude reads lights up in one color, a note it edits or creates in another. Lit notes glow while Claude works and sparks run along their links; the other notes dim, and a counter in the corner shows the notes read out of all notes in the vault ("3 / 372"). When Claude finishes its turn, everything fades out slowly.

Turn it on with `/engram:setup live`, which copies the plugin into `<vault>/.obsidian/plugins/engram-live/`. Then, in Obsidian, open Settings → Community plugins, turn off Restricted mode, enable **engram live graph** and open the graph view. The plugin's settings hold the colors, the fade time, the sparks, the dimming and the counter; the command *Reset the live graph* fades it out at once. To turn it off, disable the plugin.

How it works: this plugin ships a hook (`hooks/live.sh`) that runs in the background after Claude's Read, Edit and Write tools and when a turn stops. If a vault in the project folder, its parent or its grandparent (or one level below one of them) has `.obsidian/plugins/engram-live/live.jsonl`, the hook appends one line to it: the tool, the note's path inside the vault and the session id, or a stop marker. The Obsidian plugin creates that file while it is enabled, reads new lines from it and removes it when it is disabled. Without the file the hook reads its input and exits.

Privacy: nothing goes over the network, in the hook or in the plugin. The hook writes no file contents and no paths outside the vault, prints nothing (so it adds nothing to Claude's context) and stops appending past 1 MB, for example when Obsidian quit without unloading the plugin. The plugin keeps `live.jsonl` out of the vault's git with its own `.gitignore` and empties it on every start.

Limits:

- Only Read, Edit and Write light a note. A note Claude only saw through a search (its `description:` line in a grep) is not lit and not counted, and the routing block often answers from those lines alone, so a question may light nothing at all.
- The graph renderer is internal to Obsidian and undocumented; the plugin was written against Obsidian 1.15. On a version where it differs, the graph stays as it is and nothing breaks.
- Desktop Obsidian only, with the default `.obsidian` config folder. Obsidian pauses animations while its window is hidden.
- The hook needs a POSIX shell, like the other helpers: Git Bash on Windows.

## Install

Requirements: Claude Code, git. Obsidian is optional (the vault is plain Markdown). The shell helpers need a POSIX shell: built into macOS and Linux, and Git Bash on Windows; without it the skills run the same checks with Claude's own tools and git.

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
3. **Manual copy.** Copy `skills/setup`, `skills/scan`, `skills/note` and `skills/check` into `~/.claude/skills/` (Windows: `%USERPROFILE%\.claude\skills\`) and `reference/` into `~/.claude/reference/`, keeping both side by side so the skills find `../../reference/conventions.md`. The commands are then `/setup`, `/scan`, `/note` and `/check`; change `/engram:note` to `/note` in the routing block. The live graph hook does not come along this way.

### Update

```sh
claude plugin marketplace update engram
claude plugin update engram@engram
```

Then `/reload-plugins` in a running session. Auto-update for third-party marketplaces is off until you turn it on in `/plugin`.

Upgrading a vault made with 0.2 or earlier: run `/engram:setup privacy` once to choose the levels, then `/engram:check` to see which decisions to mark as inferred and which notes still need a source.

## Develop

```sh
sh tests/run.sh                          # tests for the shell helpers and the live graph hook on synthetic vaults
sh skills/check/scripts/lint.sh examples/vault date Daily Home Log
sh skills/scan/scripts/edited.sh <vault> # notes that hold your edits
claude plugin validate .                 # manifests
claude --plugin-dir .                    # try the skills without installing
```

`examples/projects/` holds two made-up projects and `examples/vault/` the vault the skills build from them. Bump `version` in `.claude-plugin/plugin.json` for every release, and the same number in `obsidian/engram-live/manifest.json`. The Obsidian plugin is plain JavaScript with no build step; to try a change, copy it into a vault's `.obsidian/plugins/engram-live/` and reload the plugin.

## Layout

```
.claude-plugin/   plugin.json and marketplace.json (this repository is both)
reference/        conventions.md: note format, layout, privacy, your edits, retrieval order, writing rules
skills/setup/     setup skill and its templates (layout, hub, MOC, status, proposal, routing, deny rules, graph, Bases)
skills/scan/      scan skill, the brief each project's subagent gets, and scripts/edited.sh
skills/note/      note skill
skills/check/     health check skill and scripts/lint.sh
hooks/            live graph hook: hooks.json and live.sh
obsidian/         engram-live, the live graph plugin for Obsidian
examples/         synthetic sample projects and the vault built from them
tests/            run.sh
```
