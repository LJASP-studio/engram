---
name: check
description: Health check for the engram vault (links, orphans, indexes, missing fields or sources, stale or missing code paths, privacy rules, pending proposals, likely duplicates); reports, and fixes on request.
argument-hint: "[--fix]"
disable-model-invocation: true
---

# Vault health check

Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` and the vault's `.engram.json` (find the vault as the conventions say).

## 1. Run the checks
```sh
sh "${CLAUDE_SKILL_DIR}/scripts/lint.sh" "<vault>" date "<folders.daily>" "<hub>" "<log>"
```
Output: one finding per line (`CHECK<TAB>path<TAB>detail`) and a `SUMMARY` block.
- Errors: `MISSING_FRONTMATTER`, `MISSING_DESCRIPTION`, `MISSING_DATE`, `MISSING_SOURCE` (a note in a role folder, a decision or a note with `code` has no `source`), `BROKEN_LINK`, `ORPHAN` (no other note links to it), `NOT_IN_MOC`, `NOT_IN_DAILY` (body changed today but today's daily note does not link it), `CODE_PATH_MISSING` (a `code` path does not exist under the projects root), `PROJECTS_ROOT_MISSING` (`projectsRoot` in `.engram.json` is not a folder, so the code, staleness and privacy checks did not run).
- Warnings: `NO_MOC`, `DUPLICATE_NAME` (two notes share a file name, so links are ambiguous), `LIKELY_DUPLICATE`, `STALE` (files under the note's `code` paths changed in commits after the project's `lastScan` commit and after the note was last committed; any later commit of the note counts as a review), `INFERRED_UNMARKED` (a decision sourced only by commits has no `confidence`), `PROPOSAL_PENDING`, `PRIVACY_UNSET`, `PRIVACY_MISMATCH` (`.engram.json` and the read-deny rules disagree), `PRIVACY_NONE_NOTES` (a note cites a `none` folder), `DAILY_CHECK_SKIPPED`, `DAILY_CHECK_BY_DATE` (the vault has no commit from before today, so notes dated today were checked instead of body changes).
- Counts: `INFERRED` (decisions waiting for the user's confirmation), `NOTES`.

No `sh` on this machine (Windows without Git Bash): do the same checks with Grep, Glob and git. Links are `[[Target]]`, `[[Target|alias]]` or `[[Target#heading]]`; a target resolves to any file with that name, case-insensitive, ignoring folders.

Then look at the list of note titles per folder for duplicates the script cannot see (same subject, different words). Name them as likely duplicates; do not decide alone.

## 2. Report
A short table: check, count, the first few paths. Say "clean" when there are no errors. Mention pending proposals and inferred decisions by count.

## 3. Fix (only if `$ARGUMENTS` has `--fix` or the user says yes)
First commit pending vault changes as `chore: snapshot manual edits` if `git -C <vault> status --porcelain` is not empty. On notes that `sh "${CLAUDE_SKILL_DIR}/../scan/scripts/edited.sh" "<vault>" <vault-relative note paths>` prints, make only the changes the conventions allow (Your edits); anything more becomes a proposal. Respect `privacy` (conventions): read nothing in a `none` folder, only names in a `structure` folder; a fix that needs more becomes a question to the user or a re-scan.
- Missing description: one sentence written from the note's body.
- Missing date: the date of the fact from its source (`git log --diff-filter=A --format=%ad --date=short -- <file> | tail -1` in the source repository, a changelog or tag date). If no source gives one, ask; never invent.
- Missing source: find the document, changelog entry, commit or tag the note rests on and add it. If none exists, ask the user; what they state cites `conversation <today>`.
- Code path missing: find where it went (`git -C <project> log --follow --name-status --format=%h -- <path>` or a Glob for the file name) and update the path; if the code is gone, remove the path and say so in the note.
- Stale: compare the note with the changed files (`git -C <project> log --format="%h %s" <lastScan commit>..HEAD -- <path>`). Update what changed, or re-scan the project with `/engram:scan <project>`. When the note is still right, add the newest of those commits to its `source`, which records the review and clears the warning.
- Inferred unmarked: add `confidence: inferred`. Inferred decisions: list them and ask the user which to confirm; a confirmed one gets `confidence: confirmed`.
- Pending proposal: show what it changes and ask; apply or drop it as the conventions say.
- Projects root missing: ask where the projects folder is and correct `projectsRoot`.
- Privacy: run `/engram:setup privacy` for `PRIVACY_UNSET` and `PRIVACY_MISMATCH`; for `PRIVACY_NONE_NOTES`, ask whether to delete those notes or change the folder's level.
- Broken link: point it to the existing note that was meant, or remove the brackets. Never create empty notes to satisfy a link.
- Orphan or not in MOC: add `- [[Note]]: description` to the folder MOC, and link it from one related note.
- Not in daily: add it to the `Related:` line of today's daily note.
- Duplicates: propose a merge (which note stays, what moves over) and follow the conventions' Rename, move, merge rules; merging deletes a file, so do it only after a yes.
- While a note is open for a fix, also add what the note format needs and is missing: `# Title`, tags, the up-link or `Related:` line.
- Every note whose body you changed goes into today's daily note too.

After fixing, run the script again, append one line `- <today> maintenance | <what changed>` to the log, and commit only the files you touched: `git -C <vault> add -- <paths>`, then `git -C <vault> commit -m "chore: vault maintenance"`. Never push.
