# Brief for one project scan

Fill the `{{…}}` fields and send this to a read-only subagent.

---

You are scanning one project so a notes vault can point Claude straight to the right files later. Read only; do not create, edit or delete any file, and do not run commands that change anything.

- Project: `{{project}}` at `{{path}}` (paths in your answer are relative to `{{projectsRoot}}`, forward slashes).
- Privacy level: {{level}}. `full`: you may read documents, code and git history. `structure`: use only folder and file names (Glob, `git ls-files`, `git diff --name-only`); open no file and read no commit message or diff; propose only the project hub with a code map of the main folders, saying the map comes from names only.
- Never open files matching: {{exclude}}.
- Mode: {{mode}} (full, or only the changes since `{{sinceCommit}}`: {{changeSummary}}).
- Vault language: {{language}}. Write titles, descriptions and bodies in it. Frontmatter keys and tags stay English: `description`, `date`, `source`, `code`, `tags`, `confidence`.
- Notes that already exist for this project (title: description):
{{existingNotes}}

## Read, in this order (full level)
1. `README*`, `CLAUDE.md`, `AGENTS.md`, `CHANGELOG*`, `docs/` (architecture, ADRs, decisions, specs), manifests, and status files (`STATE*`, `STATUS*`, `TODO*`, `ROADMAP*`, `NEXT*`, `HANDOFF*`).
2. The top two levels of the source tree, to map modules to folders. Open a source file only to confirm what a module does.
3. Git, if it is a repository: `git log --reverse --format="%h %ad %s" --date=short | head -20`, `git tag --sort=creatordate --format="%(refname:short) %(creatordate:short)"`, and `git log --diff-filter=A --format=%ad --date=short -- <file> | tail -1` to date a file.
4. Markdown notes or an Obsidian vault inside the project: summarise what is useful and cite the file; never copy notes over.

Skip dependencies, build output, lock files, generated code, binaries, `.env*`, keys, certificates and anything that looks like a secret or personal data.

## Propose
- One project hub: what it is, stack, how to run and test it, and a code map (main folders and entry points in the code field).
- One note per main feature or module, with the files or folders that implement it.
- One note per decision that a source states (ADR, doc, changelog, a commit that says why). Title starts with the decision's date. When every source of a decision is a commit or a tag, add `confidence: inferred`.
- One note per release (tag or changelog entry), dated by the tag or entry.
- One tech note per framework, library or service that matters to the project.
- One STATUS block, only from a status file or an `Unreleased` changelog section: what is in progress now, what is next, open questions, what was tried and did not work. Every line cites its file. Leave a section empty rather than guess; no material, no block.

Each note: one subject, two to six sentences, safe to show anyone. Put related notes in `links:`, not in a `Related:` line in the body. For an update of a hub or index note, write only its lead text; the merge keeps its content list and adds new notes to it. Every note needs a source (file path, `repo@commit`, tag or URL) and a date taken from that source: the changelog date, tag date, commit date, the date in the document, or the date the cited file was added. Never invent a date or a fact. If you cannot source it, leave it out. For an existing note, propose an update instead of a new note.

## Answer format
Return only blocks like these, nothing else:

```
=== NOTE
action: new            # or: update <existing title>
folder: projects/{{project}}   # or: decisions, releases, tech
title: Short specific title
description: One sentence, at most about 160 characters.
date: YYYY-MM-DD
source: [path/or/commit, ...]
code: [path/to/dir/, path/to/file.ext]
tags: [..]
confidence: inferred   # decisions sourced only from commits or tags; omit otherwise
links: [Project hub title, other titles]
body:
Two to six sentences.
=== END

=== STATUS
date: YYYY-MM-DD       # date of the newest cited line
source: [path, ...]
now:
- line (path)
next:
- line (path)
questions:
tried:
=== END
```
