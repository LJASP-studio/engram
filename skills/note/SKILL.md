---
name: note
description: After a task, write or update an engram vault note (decision, release, feature, fix, research) and the project's status note; link, log and commit the vault locally. Use when work is done or the user asks to note it.
argument-hint: "[what to note]"
allowed-tools: Read Grep Glob Write Edit Bash(git -C * status *) Bash(git -C * log *) Bash(git -C * add -- *) Bash(git -C * add -A) Bash(git -C * commit -m *) Bash(sh *edited.sh*)
---

# Write a note

Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` and the vault's `.engram.json` (find the vault as the conventions say). Subject: `$ARGUMENTS`, or what was just done in this conversation. Never write about a folder whose privacy level is `none`.

1. **Decide whether it is worth a note.** Decisions with their reason, releases, new or changed features, fixed bugs whose cause was not obvious, research results, where something lives in the code. Not chit-chat, not secrets, not personal data. When in doubt, ask in one line or skip.
2. **Search first.** Glob the likely title; Grep `^description:` and the key words across the vault. If a note covers the subject, update it (facts, `code:` paths, source) rather than writing a second one. If it already says everything, change nothing to it.
3. **Protect the user's edits.** If `git -C <vault> status --porcelain` is not empty, commit those changes first: `git -C <vault> add -A`, then `git -C <vault> commit -m "chore: snapshot manual edits"`. For each note you will change, run `sh "${CLAUDE_SKILL_DIR}/../scan/scripts/edited.sh" "<vault>" "<vault-relative note path>"`; if it prints the note, make only the changes the conventions allow (Your edits) and put any other rewording or removal into a proposal.
4. **Write.** Pick the type from the conventions' type list. Folder by type: decision → decisions folder, title `YYYY-MM-DD Title`; release → releases folder; feature or module → the project folder; tool → tech folder; research → the folder of what it is about. Full frontmatter (conventions); a decision the user stated or confirmed in this session cites `conversation <today>` and needs no `confidence`. Two to six sentences. Link the project hub and at least one related note; add a backlink in the project hub or the related note when the new note matters there. If the note shows a theme that has a concept note, add a line for it to that concept note. On an update, keep the date unless the fact itself is new, and add the new source to the source list.
5. **Status note.** For work on a project, open `<projects>/<Name>/<Name> status.md` (create it from `${CLAUDE_SKILL_DIR}/../setup/templates/status.<language>.md` if missing, and link it from the project hub). Add one dated line to the first section (now) with the session's outcome; add follow-ups to the second (next) and remove the items this session finished; add questions it raised to the third and remove the ones it answered; add approaches that failed, with why, to the fourth (tried and did not work). Change no other line. Set `date` to today.
6. **Index.** Add or update the note's line in its folder MOC: `- [[Note]]: description`. When that MOC is a project hub, add the link to the hub's list in the hub's own style.
7. **Daily note.** Open `<daily>/<today>.md`; if it is missing, create it as the conventions say and add it to the daily MOC. Add the note and the status note to its `Related:` line and, if useful, half a sentence to the summary. If the summary now says something new about the day, update the daily note's description and its MOC line to match.
8. **Log.** Append `- <today> <type> | <Title>`, adding ` (updated)` after the title for an update; a proposal gets `- <today> proposal | <Title>`.
9. **Commit locally.** Stage only the files you touched: `git -C <vault> add -- <paths>`, then `git -C <vault> commit -m "docs: add <Title>"` (or `docs: update <Title>`); put the reason in a second `-m` when there is one. Never add a remote, never push. If the vault is not a git repository, say so and skip.

Reply in one or two lines: the note's path, whether it was new or updated, and any proposal written.
