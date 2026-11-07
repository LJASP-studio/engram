# engram

A second brain for [Claude Code](https://code.claude.com): one Obsidian vault per machine, made of small linked notes. The notes keep what the code does not say (why a decision was made, when something changed, how projects connect) and point to the files that matter. An engram is the trace a memory leaves in the brain.

## How it works

engram is a Claude Code plugin. It sets up a vault inside your projects folder and keeps it in a local git repository with no remote.

```
projects/
├── CLAUDE.md     + a short routing block
├── api/          your projects, untouched
├── web/
└── brain/        the vault: Projects, Decisions, Releases, Tech, Concepts, Daily, Log
```

Each note has a one-line description, a date and source, and the code paths it is about:

```markdown
---
description: Documents and undo history live in one SQLite file per vault; saves are atomic.
date: 2026-01-10
source: inkwell/docs/decisions/0001-storage-sqlite.md
code: [inkwell/src/editor/]
tags: [decision]
---
```

The routing block tells Claude to grep the `description:` lines first, open at most three notes and go to the code they name.

## Skills

| Skill | What it does |
|---|---|
| `/engram:setup [en\|tr]` | Sets up the vault: note language, folders, a privacy level per project, the routing block, read-deny rules and local git. |
| `/engram:scan [project …]` | Reads each project (docs, code, git history) and proposes notes with sources. Writes nothing before your OK, and later rescans only what changed. |
| `/engram:note` | After a task: writes or updates a note and the project's status note, then commits the vault. |
| `/engram:check [--fix]` | Finds missing sources, broken links, code paths that no longer exist, stale notes and duplicates. |

Only `note` sits in Claude's context; the others run when you type them.

## What a vault changes

I measured it on my own workspace (several projects, about 370 notes): 60 questions, each asked twice with and twice without the vault on Claude Sonnet 5.5, every answer graded against a key.

- Cost per question was the same (ratio 0.99).
- Where the code is silent, answers were right more often: history 15 vs 11 out of 16, decisions 12 vs 10 out of 16, questions across projects 12 vs 9 out of 14. Per fully correct answer, the vault came out about 10 percent cheaper, within the run-to-run noise.
- Change plans got worse: Claude trusted the notes and missed files.
- With the vault, Haiku 5.5 answered a separate set of 20 questions as fully as Opus 5.5, at about a fortieth of the cost.

One workspace, and git history was off during the test, so read these as a direction. An earlier run on Opus 5 used 46 percent fewer tokens with the vault; current models no longer show that.

## Privacy and your edits

Each machine decides what may be read, per project folder: `full` (docs, code, git history), `structure` (file names only) or `none` (skipped). `.env` files, keys and credentials are never read. Setup also writes these as read-deny rules in `.claude/settings.json`, so they hold in every session started in that folder.

engram itself sends nothing anywhere: no network calls, no remote, no push. What a skill reads does go to the model, so check your employer's policy before you use it on work code. Keep the vault in a plain local folder (iCloud Drive on Windows can corrupt files) and pause file sync during a scan.

engram never overwrites your text. It tells your edits from its own with git; on a note you edited it only adds lines, and anything else becomes a proposal in `Proposals/` for you to apply or drop.

## Live graph

An optional Obsidian plugin that lights up, in the graph view, the notes Claude reads, edits or finds in a search, and fades them out when Claude is done. Turn it on with `/engram:setup live`, then enable "engram live graph" under Obsidian's community plugins. A background hook writes one line per touched note to a file inside the vault; it never goes online. Desktop Obsidian only.

## Install

You need Claude Code and git; Obsidian is optional.

```sh
claude plugin marketplace add muazfurkan/engram
claude plugin install engram@engram
```

Then start `claude` in the folder that holds your projects and run `/engram:setup en` and `/engram:scan`. To update: `claude plugin marketplace update engram`, then `claude plugin update engram@engram`.

On Windows the shell helpers need Git Bash. engram is written for it but has not been tried on a real Windows machine yet; please open an issue if something breaks. Where plugin marketplaces are blocked, clone this repository and start Claude Code with `claude --plugin-dir path/to/engram`.

## Develop

```sh
sh tests/run.sh            # shell helpers and the live graph hook
claude plugin validate .
claude --plugin-dir .      # try it without installing
```

The note format and every rule are in [reference/conventions.md](reference/conventions.md); `examples/` holds two made-up projects and the vault built from them.

## License

[MIT](LICENSE)
