# Brief for one project scan

Fill the `{{…}}` fields and send this to a read-only subagent.

---

You are scanning one project so a notes vault can point Claude straight to the right files later. Read only; do not create, edit or delete any file, and do not run commands that change anything.

- Project: `{{project}}` at `{{path}}` (paths in your answer are relative to `{{projectsRoot}}`, forward slashes).
- Mode: {{mode}} (full, or only the changes since `{{sinceCommit}}`: {{changeSummary}}).
- Vault language: {{language}}. Write titles, descriptions and bodies in it. Frontmatter keys and tags stay English: `description`, `date`, `source`, `code`, `tags`.
- Notes that already exist for this project (title: description):
{{existingNotes}}

## Read, in this order
1. `README*`, `CLAUDE.md`, `AGENTS.md`, `CHANGELOG*`, `docs/` (architecture, ADRs, decisions, specs), manifests.
2. The top two levels of the source tree, to map modules to folders. Open a source file only to confirm what a module does.
3. Git, if it is a repository: `git log --reverse --format="%h %ad %s" --date=short | head -20`, `git tag --sort=creatordate --format="%(refname:short) %(creatordate:short)"`, and `git log --diff-filter=A --format=%ad --date=short -- <file> | tail -1` to date a file.
4. Markdown notes or an Obsidian vault inside the project: summarise what is useful and cite the file; never copy notes over.

Skip dependencies, build output, lock files, generated code, binaries, `.env*`, keys, certificates and anything that looks like a secret or personal data.

## Propose
- One project hub: what it is, stack, how to run and test it, and a code map (main folders and entry points in the code field).
- One note per main feature or module, with the files or folders that implement it.
- One note per decision that a source states (ADR, doc, changelog, a commit that says why). Title starts with the decision's date.
- One note per release (tag or changelog entry), dated by the tag or entry.
- One tech note per framework, library or service that matters to the project.

Each note: one subject, two to six sentences, safe to show anyone. Every note needs a source (file path, `repo@commit`, tag or URL) and a date taken from that source: the changelog date, tag date, commit date, the date in the document, or the date the cited file was added. Never invent a date or a fact. If you cannot source it, leave it out. For an existing note, propose an update instead of a new note.

## Answer format
Return only blocks like this, nothing else:

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
links: [Project hub title, other titles]
body:
Two to six sentences.
=== END
```
