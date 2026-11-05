---
name: scan
description: Scan the projects in this folder into the engram vault, one subagent per project, writing only sourced notes that point to code; shows a plan first, respects privacy levels and your own edits.
argument-hint: "[project ...] [--full]"
disable-model-invocation: true
---

# Scan projects into the vault

Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` and the vault's `.engram.json` first. Find the vault as the conventions say. This skill reads projects and writes only inside the vault. It never edits a project, never adds a remote, never pushes.

Arguments: `$ARGUMENTS`. Project folder names limit the scan to those projects; `--full` ignores `lastScan`.

## 1. Find projects
- If `.engram.json` has no `privacy` block, stop and ask the user to run `/engram:setup privacy` first.
- List the top-level folders of the projects root by name (not the vault, not hidden folders). Drop every `none` folder now: never look inside it. A folder missing from `privacy.projects`: ask the user for its level (`full`, `structure`, `none`) before looking inside, record the answer in `.engram.json`, and for `none` add its read-deny rule as `/engram:setup` step 6 does.
- Keep a folder as a project if it has any of: `.git`, a README, `CLAUDE.md` or `AGENTS.md`, `docs/`, a manifest (`package.json`, `pyproject.toml`, `requirements.txt`, `*.csproj`, `*.sln`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle*`, `Package.swift`, `project.yml`, `composer.json`, `Gemfile`), three or more Markdown files, or an Obsidian vault (`.obsidian/`). If a folder has none of these but its subfolders do, treat each subfolder as a project with the folder's level.
- Never read files matching `privacy.exclude`, `.env` files, keys or credentials.

## 2. Decide what to scan
- Git project with `lastScan[<project>].commit` and no `--full`: run `git -C <project> diff --stat <commit> HEAD` and, for `full` projects, `git -C <project> log --format="%h %ad %s" --date=short <commit>..HEAD` (`structure` projects: `git -C <project> diff --name-only <commit> HEAD` only). No new commits: skip it. Otherwise scan only what changed, plus notes that cite changed files.
- Otherwise a full scan.
- Collect the vault notes that already belong to the project: Grep `^description:` in its project folder, and Grep the project name across the vault. These go into the brief so the subagent proposes updates, not duplicates.

## 3. One subagent per project
Fill `${CLAUDE_SKILL_DIR}/brief.md` for each project, with its privacy level and the exclude patterns, and start the subagents in parallel, at most five at a time. A large `full` project (roughly 200+ commits or 15+ documents) gets two briefs with a stated slice each, so neither subagent runs out of context: documents, code map and status (hub, features, modules, tech, status note) in one; git history, decisions, milestones and data in the other. Tell each which notes the other writes. Use a read-only agent (the Explore agent where available); subagents never write files. Each returns proposed notes in the brief's format.

## 4. Merge (nothing is written yet)
- Tech notes: one per tool across all projects. Merge proposals for the same tool and link every project that uses it.
- For each proposal, search the vault: Glob the title, Grep similar titles and the `description:` lines. If a note on the subject exists, it becomes an update of that note (add facts, extend the source and code lists, keep its date unless the fact is new) instead of a new note.
- Drop any proposal without a source, with an invented date, or with secrets, customer or personal data.
- A decision whose every source is a commit or a tag gets `confidence: inferred`. Notes from a `structure` project get `visibility: internal`.
- Status note: if the project has no `<Name> status` note, plan one from the subagent's STATUS block (template `${CLAUDE_SKILL_DIR}/../setup/templates/status.<language>.md`); sections without sourced lines stay empty. An existing status note is left to `/engram:note`.
- Concept notes: look across projects for themes that notes in two or more projects already show (the conventions' concept notes). For each theme the notes support, plan one new or updated concept note listing those notes grouped by project, and the concept link on each listed note's `Related:` line. Never a concept that only one project shows, never a theme a note does not state.
- Your edits: run `sh "${CLAUDE_SKILL_DIR}/scripts/edited.sh" "<vault>" <every existing note an update would change, as vault-relative paths>` (without a shell, the git rule in the conventions). On a note it prints, keep only the changes the conventions allow; the rest of that update becomes a proposal.

## 5. Show the plan and wait
Show per project: new notes (titles), updates (titles), proposals (titles, each with one line on what it would change), status notes to create, concept notes, and the decisions marked `confidence: inferred`. Ask for an OK. Apply any changes the user asks for and show the plan again if it changed a lot. Write nothing before the OK.

## 6. Write
- First, if `git -C <vault> status --porcelain` is not empty, commit those changes as the user's: `git -C <vault> add -A`, then `git -C <vault> commit -m "chore: snapshot manual edits"`. Then run `edited.sh` again on the planned updates: the user may have edited notes while the plan waited. Newly printed notes get only the allowed additions, the rest becomes a proposal. Read each note again just before changing it.
- Write new notes in the right folder with full frontmatter (conventions). Project hub: `<projects>/<Name>/<Name>.md`; features, modules and the status note next to it. Write updates and concept notes. Write each proposal to `<proposals>/<Title>.proposal.md` and leave its note untouched.
- Add a line `- [[Note]]: description` to each touched folder's MOC; new project hubs go into the projects MOC and the hub's projects list; a new status note goes into its project hub.
- Link every new or changed note from today's daily note (create it if missing and add it to the daily MOC). Proposals are not linked.
- Append one log line per new note, one per proposal (`- <today> proposal | <Title>`) and one summary line per project (`- <today> scan | <project>: N new, M updated, P proposals`).
- Set `lastScan[<project>]` in `.engram.json` to `{ "commit": "<git -C <project> rev-parse --short HEAD>", "date": "<today>" }` (`null` commit for a folder without git).

## 7. Check and commit
Run the check script (`sh "${CLAUDE_SKILL_DIR}/../check/scripts/lint.sh" <vault> date <daily> <hub> <log>`) and fix any error this scan created. Then stage the files this scan wrote or changed (`git -C <vault> add -- <paths>`) and commit: `git -C <vault> commit -m "docs: scan <projects>"`. Report per project: new notes, updated notes, proposals waiting for review, skipped, anything left unsourced, and the inferred decisions waiting for the user's confirmation.
