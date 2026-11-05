# Vault conventions

Every engram skill follows these rules. Read them once per task.

## Config: `.engram.json`

Each vault has a `.engram.json` at its root. Skills read it first and never guess names.

```json
{
  "version": 1,
  "language": "en",
  "projectsRoot": "..",
  "hub": "Home",
  "log": "Log",
  "views": "Views",
  "folders": {
    "projects": "Projects",
    "decisions": "Decisions",
    "releases": "Releases",
    "tech": "Tech",
    "concepts": "Concepts",
    "daily": "Daily",
    "proposals": "Proposals"
  },
  "privacy": {
    "projects": { "api": "full", "client-portal": "structure", "payroll": "none" },
    "exclude": [".env", ".env.*", "*.pem", "*.key"]
  },
  "lastScan": {}
}
```

- `projectsRoot` is relative to the vault. Code paths in notes are relative to it.
- The structure is English in every vault: role folders and their indexes, the hub, the log, the views, the frontmatter keys (`description`, `date`, `source`, `code`, `tags`, `confidence`, `visibility`) and the type tags. `language` (`en` or `tr`) sets the language of note text, of titles about your projects and of the routing block. Folders inside a project (feature groups) and your own topic folders may use that language too.
- An existing vault may map its own folder names here; skills use whatever the config says. A missing `proposals` key means `Proposals`.
- `lastScan` maps a project folder to `{ "commit": "<sha>", "date": "YYYY-MM-DD" }` (`commit` is `null` for a folder that is not a git repository).
- `privacy` is per machine; see Privacy.

## Finding the vault

Glob for `.engram.json` in this order and take the first hit: the current folder, its direct subfolders, the parent folder, the parent's direct subfolders, then two levels up the same way. A session started inside one project still finds the vault next to it. No hit: tell the user to run `/engram:setup`.

## Privacy

Each machine decides what an LLM may read. `privacy.projects` gives every project folder one level:

- `full`: contents may be read (documents, code, git history).
- `structure`: folder and file names only (Glob, `git ls-files`, `git diff --name-only`); no file contents, no commit messages, no diffs. Its notes carry `visibility: internal`.
- `none`: skipped entirely. Never listed, read, scanned or written about.

`privacy.exclude` holds file patterns no skill reads in any project (`.env`, keys, certificates, credentials). A folder missing from `privacy.projects` is asked about before anything inside it is read, and the answer is recorded.

The user can change a level at any time, for example to open a `none` folder again: `/engram:setup privacy` rewrites both the config and the rules below. Every skill respects the levels, `check --fix` included: no contents of a `structure` folder, nothing at all in a `none` folder.

`/engram:setup` also writes these as read-deny rules in `permissions.deny` of `<projects root>/.claude/settings.json`: `Read(/<folder>/**)` for every `none` folder and `Read(./**/<pattern>)` for every exclude pattern. Claude Code then refuses them to its file tools (Read, Grep, Glob, Edit, Write) and to the shell file commands it recognises, in any session started in the projects root, not only during a scan. A session started inside a project folder reads that folder's own settings instead. `/engram:check` warns when the config and the rules disagree, and when notes cite a `none` folder.

## Note format

```markdown
---
description: One sentence on what the note says, so it can be picked without opening it.
date: 2026-03-14
source: api/CHANGELOG.md (1.4.0)
code: [api/src/auth/, api/src/middleware/session.ts]
tags: [decision]
---
# Title

Two to six sentences or bullets. One thing per note.

Related: [[Project hub]] · [[Other note]]
```

- `description`: required. One sentence, at most about 160 characters, no line breaks. Say what is inside and when it is useful.
- `date`: required, `YYYY-MM-DD`. It is the date of the fact (commit, tag, changelog entry, document date). Never invent one. If the source has no date, use the date the note was written.
- `source`: required for notes in the projects, decisions, releases, tech and concepts folders (MOCs and status notes excepted) and for any note with `code`. A path relative to the projects root, a commit (`repo@abc1234`), a tag, a URL, or `conversation YYYY-MM-DD` for something the user stated in a session. Several sources go in a list.
- `code`: optional list of files or folders the note describes, relative to the projects root, forward slashes. This is what lets Claude jump straight to the right files. Every path must exist; `/engram:check` reports the ones that do not.
- `confidence: inferred`: on a decision whose only sources are commits or tags (the reason was read from commit messages). It stays until the user confirms the decision; then it becomes `confidence: confirmed`.
- `visibility: internal`: on notes about a `structure` project.
- Titles are short, specific and safe to show anyone. File name = title + `.md`. Decisions start with the date: `2026-03-14 Sessions move to Redis.md`. Releases: `<Project> vX.Y.Z.md`.
- Body: plain wikilinks `[[Note]]`, never Markdown links to notes. Each content note links to at least its project hub or folder MOC and one related note. MOCs, daily notes, the hub and the log only need their up-link.
- Never write secrets, tokens, passwords, `.env` values, customer data or personal data. Never copy whole files; summarise and point to the path.

## Layout

- Hub: `<hub>.md` at the vault root. Links every folder MOC, every project hub and the log.
- MOC (map of content): one per folder, named after the folder, inside it: `Decisions/Decisions.md`. Tag `moc`. One line per note in the folder: `- [[Note]]: description`. Subfolders get their own MOC, linked from the parent MOC.
- Project hub: `Projects/<Name>/<Name>.md`. What the project is, stack, how to run and test, a short code map (`code:` paths), and links to its feature, decision and release notes and its status note.
- Status note: `Projects/<Name>/<Name> status.md`, tag `status`, from `status.<language>.md` in the setup templates. Four sections in this order: now, next, open questions, tried and did not work (headings in the note language). One dated line per item: `- 2026-03-14 Sessions moved to Redis; login works again.` `scan` creates it from sourced material only (a STATE or TODO file, an `Unreleased` changelog section, each line citing its file) and leaves a section empty rather than guessing; `note` keeps it current. It needs no `source`.
- Tech notes: one per tool or framework, shared by all projects that use it. They link every project that uses them; these cross-project hubs are what make the graph look like a brain.
- Concept notes: one per theme that cuts across projects and folders (a principle, a quality such as security or privacy, a technique such as determinism or localisation). Write one only when notes in two or more projects already show the theme. The body says in two or three sentences what the theme means here, then lists the notes that show it, grouped by project, one line each with what that note adds. `source` lists the sources of those notes; `code` lists the main paths; tag `concept`. A vault older than this rule may lack the concepts folder: add it to `.engram.json` and create its MOC before writing the first concept note.
- Daily note: `<daily>/YYYY-MM-DD.md`, tag `daily`, heading `# YYYY-MM-DD`, a one- or two-line summary and a `Related:` line linking every note written or changed that day.
- Views: the views folder holds Obsidian Bases tables (decision table, release table, orphans) and no notes.
- Proposals: the proposals folder holds proposed changes to notes the user edited (see Your edits). No MOC; the check lists them.
- Log: `<log>.md` at the root. Append only, one line per change, plain text (no wikilinks, so it does not become a giant graph node):
  `- 2026-03-14 decision | 2026-03-14 Sessions move to Redis`

## Retrieval order (what the routing block tells Claude)

1. Grep `^description:` across the vault for the question's key words, with four lines of context so `source:` and `code:` come in the same result. Most questions end here: open the code paths.
2. If nothing matches or the question is broad, the hub, then the folder MOC that fits. A question that spans projects ("where do we handle X anywhere") starts at the concepts MOC; "where does X stand, what is next" starts at the project's status note.
3. Open at most three notes.
4. Search the code only if the notes do not answer.

Every extra step is a full model turn that re-reads the whole context, so the order is chosen to reach the code in as few turns as possible. Keep `description` the first frontmatter key and `code` within the next four lines, so one grep returns both.

## Your edits

engram never overwrites text the user wrote. It tells the user's text from its own with git, so notes need no markers:

- Every engram commit message starts with `docs: ` or `chore: `.
- Before any skill writes, it commits whatever is pending in the vault as `chore: snapshot manual edits`. Those are the user's edits, now marked as theirs.
- A note carries the user's edits when it has uncommitted changes, or when any commit in its history (renames followed) is a snapshot commit, a `docs: merge` commit (it may carry the user's lines over) or a commit engram did not make (the user's own commits, an Obsidian git plugin's backups). Once marked, it stays marked. A vault without commits marks every note.
- `sh <skills>/scan/scripts/edited.sh <vault> [note ...]` prints those notes; give notes as paths relative to the vault (absolute paths inside it work too). It exits with 2 and names any path it cannot find: fix the path and run it again, never read silence as "not edited". Without a shell, run `git -C <vault> status --porcelain -- <note>` and `git -C <vault> log --follow --format=%s -- <note>` and apply the same rule.
- Check right before writing, after the snapshot: the user may have edited a note while a plan waited for an OK. Read the note again just before changing it.

On a note with the user's edits, a skill may only make these changes: add a line to an index or a `Related:` line; add an item to `source` or `code`; add a dated line to a status note, or remove an item there that the current task finished or answered; add words to the end of a daily note's summary; set `date`, `confidence` or `visibility`; keep an index line's description equal to its note's description; point a link at a note's new name after a rename, move or merge. Anything else that rewords, moves or removes text goes to a proposal instead:

- File `<proposals>/<Title>.proposal.md` (one per note) from `proposal.md` in the setup templates: frontmatter with `description`, `date`, `proposal_for: <vault path of the note>`, the new `source` items and tag `proposal`; a line on why; a short list of the changes; the full proposed note inside a `~~~~markdown` fence, so its links stay out of the graph. If a proposal for the note is already waiting, the new one starts from it and keeps its changes that still apply.
- Log line `- <today> proposal | <Title>`. The note itself is not touched.
- The user decides. To apply: merge the proposal into the note keeping every line the user wrote, delete the proposal file, commit `docs: apply proposal <Title>`. To drop: delete the proposal file, commit `chore: drop proposal <Title>`.

## Rename, move, merge

The vault may be reorganised as it grows, under these conditions:

- Use `git -C <vault> mv`, so history (and the user-edit mark) follows the file.
- In the same step, update every link to the old name: Grep `\[\[<old name>(\||#|\]\])` across the vault and replace the name, keeping any `|alias` or `#heading`. Update the MOC lines, and `.engram.json` when the hub, the log or a role folder changes name. Old log lines stay as they are.
- One commit per change: `docs: rename <old> to <new>`, `docs: move <title> to <folder>`, `docs: merge <a> into <b>`. Append a log line `- <today> maintenance | renamed <old> to <new>` (or moved, merged).
- Run the check afterwards; it must be clean before the next change.
- A merge keeps every fact, source and code path of both notes and every line the user wrote. Removing the merged file deletes a file: ask the user first.

## Types

Used in the log and in tags: `decision`, `release`, `feature`, `module`, `fix`, `research`, `tech`, `concept`, `status`, plus `scan`, `proposal`, `maintenance` and `setup` for vault work. Vault commits use Conventional Commits: `docs: add <Title>`, `docs: update <Title>`, `docs: scan <projects>`, `docs: apply proposal <Title>`, `docs: rename …`, `docs: move …`, `docs: merge …`, `chore: drop proposal <Title>`, `chore: snapshot manual edits`, `chore: update privacy`, `chore: vault maintenance`, `chore: set up the vault`.

## Writing rules

- Search before writing: grep titles and `description:` lines. Update an existing note rather than adding a second one on the same subject.
- When in doubt, do not write. No note without a source.
- Before writing: snapshot pending vault changes (Your edits), and check whether the notes you will change carry the user's edits.
- After writing: add or update the note's line in its folder MOC, link it from today's daily note, append a log line, then commit the vault locally.
- On an update, keep the note's date unless the fact itself is new; add the new source.
- Git: stage only the files the skill touched (`git -C <vault> add -- <paths>`) and commit with a message from the type list. Never add a remote, never push.
