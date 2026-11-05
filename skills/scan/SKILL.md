---
name: scan
description: Scan the projects in this folder into the engram vault, one subagent per project, writing only sourced notes that point to code; incremental via git log.
argument-hint: "[project ...] [--full]"
disable-model-invocation: true
---

# Scan projects into the vault

Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` and the vault's `.engram.json` first. Find the vault as the conventions say. This skill reads projects and writes only inside the vault. It never edits a project, never adds a remote, never pushes.

Arguments: `$ARGUMENTS`. Project folder names limit the scan to those projects; `--full` ignores `lastScan`.

## 1. Find projects
Under the projects root (from `.engram.json`), each top-level folder except the vault and hidden folders is a candidate. Keep it if it has any of: `.git`, a README, `CLAUDE.md` or `AGENTS.md`, `docs/`, a manifest (`package.json`, `pyproject.toml`, `requirements.txt`, `*.csproj`, `*.sln`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle*`, `Package.swift`, `project.yml`, `composer.json`, `Gemfile`), three or more Markdown files, or an Obsidian vault (`.obsidian/`). If a folder has none of these but its subfolders do, treat each subfolder as a project. Respect the read-deny rules; never read `.env` files, keys or credentials.

## 2. Decide what to scan
- Git project with `lastScan[<project>].commit` and no `--full`: run `git -C <project> log --format="%h %ad %s" --date=short <commit>..HEAD` and `git -C <project> diff --stat <commit> HEAD`. No new commits: skip it. Otherwise scan only what changed, plus notes that cite changed files.
- Otherwise a full scan.
- Collect the vault notes that already belong to the project: Grep `^description:` in its project folder, and Grep the project name across the vault. These go into the brief so the subagent proposes updates, not duplicates.

## 3. One subagent per project
Fill `${CLAUDE_SKILL_DIR}/brief.md` for each project and start the subagents in parallel, at most five at a time. A large project (roughly 200+ commits or 15+ documents) gets two briefs with a stated slice each, so neither subagent runs out of context: documents and code map (hub, features, modules, tech) in one; git history, decisions, milestones and data in the other. Tell each which notes the other writes. Use a read-only agent (the Explore agent where available); subagents never write files. Each returns proposed notes in the brief's format.

## 4. Merge and write
- Tech notes: one per tool across all projects. Merge proposals for the same tool and link every project that uses it.
- Before each write, search the vault: Glob the title, Grep similar titles and the `description:` lines. If a note on the subject exists, update it (add facts, extend the source and code lists, keep its date unless the fact is new) instead of writing another.
- Drop any proposal without a source, with an invented date, or with secrets, customer or personal data.
- Write new notes in the right folder with full frontmatter (conventions). Project hub: `<projects>/<Name>/<Name>.md`; features and modules next to it.

## 4b. Concept notes
After the merge, look across projects for themes that notes in two or more projects already show (the conventions' concept notes: principles, qualities such as security or privacy, techniques such as determinism or localisation). For each theme the notes support, write or update one concept note in the concepts folder, listing those notes grouped by project. Add the concept link to each listed note's `Related:` line. Never write a concept that only one project shows, and never claim a theme a note does not state.

## 5. Indexes, daily note, log, state
- Add a line `- [[Note]]: description` to each touched folder's MOC; new project hubs go into the projects MOC and the hub's projects list.
- Link every new or changed note from today's daily note (create it if missing and add it to the daily MOC).
- Append one log line per new note and one summary line per project (`- <today> scan | <project>: N new, M updated`).
- Set `lastScan[<project>]` in `.engram.json` to `{ "commit": "<git -C <project> rev-parse --short HEAD>", "date": "<today>" }`.

## 6. Check and commit
Run the check script (`sh "${CLAUDE_SKILL_DIR}/../check/scripts/lint.sh" <vault> date <daily> <hub> <log>`) and fix any broken link or orphan this scan created. Then stage the files this scan wrote or changed (`git -C <vault> add -- <paths>`) and commit: `git -C <vault> commit -m "docs: scan <projects>"`. Report per project: new notes, updated notes, skipped, and anything left unsourced.
