---
name: note
description: Write or update an engram vault note after a task (decision, release, feature, fix, research), link it from today's daily note, log it and commit the vault locally. Use when work is done or the user asks to note it.
argument-hint: "[what to note]"
allowed-tools: Read Grep Glob Write Edit Bash(git -C * status *) Bash(git -C * add -- *) Bash(git -C * commit -m *)
---

# Write a note

Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` and the vault's `.engram.json` (find the vault as the conventions say). Subject: `$ARGUMENTS`, or what was just done in this conversation.

1. **Decide whether it is worth a note.** Decisions with their reason, releases, new or changed features, fixed bugs whose cause was not obvious, research results, where something lives in the code. Not chit-chat, not secrets, not personal data. When in doubt, ask in one line or skip.
2. **Search first.** Glob the likely title; Grep `^description:` and the key words across the vault. If a note covers the subject, update it (facts, `code:` paths, source) rather than writing a second one. If it already says everything, change nothing, say so and stop.
3. **Write.** Pick the type from the conventions' type list. Folder by type: decision → decisions folder, title `YYYY-MM-DD Title`; release → releases folder; feature or module → the project folder; tool → tech folder; research → the folder of what it is about. Full frontmatter (conventions). Two to six sentences. Link the project hub and at least one related note; add a backlink in the project hub or the related note when the new note matters there. On an update, keep the date unless the fact itself is new, and add the new source to the source list.
4. **Index.** Add or update the note's line in its folder MOC: `- [[Note]]: description`. When that MOC is a project hub, add the link to the hub's list in the hub's own style.
5. **Daily note.** Open `<daily>/<today>.md`; if it is missing, create it as the conventions say and add it to the daily MOC. Add the note to its `Related:` line and, if useful, half a sentence to the summary. If the summary now says something new about the day, update the daily note's description and its MOC line to match.
6. **Log.** Append `- <today> <type> | <Title>`, adding ` (updated)` after the title for an update.
7. **Commit locally.** Stage only the files you touched: `git -C <vault> add -- <paths>`, then `git -C <vault> commit -m "docs: add <Title>"` (or `docs: update <Title>`); put the reason in a second `-m` when there is one. If `git -C <vault> status --short` shows other changes, mention them and leave them. Never add a remote, never push. If the vault is not a git repository, say so and skip.

Reply in one or two lines: the note's path and whether it was new or updated.
