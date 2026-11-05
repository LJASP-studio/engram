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
    "daily": "Daily"
  },
  "lastScan": {}
}
```

- `projectsRoot` is relative to the vault. Code paths in notes are relative to it.
- The structure is English in every vault: role folders and their indexes, the hub, the log, the views, the frontmatter keys (`description`, `date`, `source`, `code`, `tags`) and the type tags. `language` (`en` or `tr`) sets the language of note text, of titles about your projects and of the routing block. Folders inside a project (feature groups) and your own topic folders may use that language too.
- An existing vault may map its own folder names here; skills use whatever the config says.
- `lastScan` maps a project folder to `{ "commit": "<sha>", "date": "YYYY-MM-DD" }`.

## Finding the vault

Glob for `.engram.json` in this order and take the first hit: the current folder, its direct subfolders, the parent folder, the parent's direct subfolders, then two levels up the same way. A session started inside one project still finds the vault next to it. No hit: tell the user to run `/engram:setup`.

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
- `source`: required for scanned notes. A path relative to the projects root, a commit (`repo@abc1234`), a tag or a URL. Several sources go in a list.
- `code`: optional list of files or folders the note describes, relative to the projects root, forward slashes. This is what lets Claude jump straight to the right files.
- Titles are short, specific and safe to show anyone. File name = title + `.md`. Decisions start with the date: `2026-03-14 Sessions move to Redis.md`. Releases: `<Project> vX.Y.Z.md`.
- Body: plain wikilinks `[[Note]]`, never Markdown links to notes. Each content note links to at least its project hub or folder MOC and one related note. MOCs, daily notes, the hub and the log only need their up-link.
- Never write secrets, tokens, passwords, `.env` values, customer data or personal data. Never copy whole files; summarise and point to the path.

## Layout

- Hub: `<hub>.md` at the vault root. Links every folder MOC, every project hub and the log.
- MOC (map of content): one per folder, named after the folder, inside it: `Decisions/Decisions.md`. Tag `moc`. One line per note in the folder: `- [[Note]]: description`. Subfolders get their own MOC, linked from the parent MOC.
- Project hub: `Projects/<Name>/<Name>.md`. What the project is, stack, how to run and test, a short code map (`code:` paths), and links to its feature, decision and release notes.
- Tech notes: one per tool or framework, shared by all projects that use it. They link every project that uses them; these cross-project hubs are what make the graph look like a brain.
- Concept notes: one per theme that cuts across projects and folders (a principle, a quality such as security or privacy, a technique such as determinism or localisation). Write one only when notes in two or more projects already show the theme. The body says in two or three sentences what the theme means here, then lists the notes that show it, grouped by project, one line each with what that note adds. `source` lists the sources of those notes; `code` lists the main paths; tag `concept`. A vault older than this rule may lack the concepts folder: add it to `.engram.json` and create its MOC before writing the first concept note.
- Daily note: `<daily>/YYYY-MM-DD.md`, tag `daily`, heading `# YYYY-MM-DD`, a one- or two-line summary and a `Related:` line linking every note written or changed that day.
- Views: the views folder holds Obsidian Bases tables (decision table, release table, orphans) and no notes.
- Log: `<log>.md` at the root. Append only, one line per change, plain text (no wikilinks, so it does not become a giant graph node):
  `- 2026-03-14 decision | 2026-03-14 Sessions move to Redis`

## Retrieval order (what the routing block tells Claude)

1. Hub, then the folder MOC that fits the question. A question that spans projects ("where do we handle X anywhere") starts at the concepts MOC.
2. If that is not enough, grep `^description:` across the vault.
3. Open at most three notes.
4. Open the code paths those notes name. Search the code only if the notes do not answer.

## Types

Used in the log and in tags: `decision`, `release`, `feature`, `module`, `fix`, `research`, `tech`, `concept`, plus `scan`, `maintenance` and `setup` for vault work. Vault commits use Conventional Commits: `docs: add <Title>`, `docs: update <Title>`, `docs: scan <projects>`, `chore: vault maintenance`, `chore: set up the vault`.

## Writing rules

- Search before writing: grep titles and `description:` lines. Update an existing note rather than adding a second one on the same subject.
- When in doubt, do not write. No note without a source.
- After writing: add or update the note's line in its folder MOC, link it from today's daily note, append a log line, then commit the vault locally.
- On an update, keep the note's date unless the fact itself is new; add the new source.
- Git: stage only the files the skill touched (`git -C <vault> add -- <paths>`) and commit with a message from the type list. Never add a remote, never push.
