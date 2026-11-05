---
name: check
description: Health check for the engram vault (orphans, broken links, missing description or date, notes missing from the daily note or their MOC, likely duplicates); reports, and fixes on request.
argument-hint: "[--fix]"
disable-model-invocation: true
---

# Vault health check

Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` and the vault's `.engram.json` (find the vault as the conventions say).

## 1. Run the checks
```sh
sh "${CLAUDE_SKILL_DIR}/scripts/lint.sh" "<vault>" date "<folders.daily>" "<hub>" "<log>"
```
Output: one finding per line (`CHECK<TAB>path<TAB>detail`) and a `SUMMARY` block. Errors: `MISSING_FRONTMATTER`, `MISSING_DESCRIPTION`, `MISSING_DATE`, `BROKEN_LINK`, `ORPHAN` (no other note links to it), `NOT_IN_MOC`, `NOT_IN_DAILY` (body changed today but today's daily note does not link it). Warnings: `NO_MOC`, `DUPLICATE_NAME` (two notes share a file name, so links are ambiguous), `LIKELY_DUPLICATE`, `DAILY_CHECK_SKIPPED`, `DAILY_CHECK_BY_DATE` (the vault has no commit from before today, so notes dated today were checked instead of body changes).

No `sh` on this machine (Windows without Git Bash): do the same checks with Grep and Glob. Links are `[[Target]]`, `[[Target|alias]]` or `[[Target#heading]]`; a target resolves to any file with that name, case-insensitive, ignoring folders.

Then look at the list of note titles per folder for duplicates the script cannot see (same subject, different words). Name them as likely duplicates; do not decide alone.

## 2. Report
A short table: check, count, the first few paths. Say "clean" when there are no errors.

## 3. Fix (only if `$ARGUMENTS` has `--fix` or the user says yes)
- Missing description: one sentence written from the note's body.
- Missing date: the date of the fact from its source (`git log --diff-filter=A --format=%ad --date=short -- <file> | tail -1` in the source repository, a changelog or tag date). If no source gives one, ask; never invent.
- Broken link: point it to the existing note that was meant, or remove the brackets. Never create empty notes to satisfy a link.
- Orphan or not in MOC: add `- [[Note]]: description` to the folder MOC, and link it from one related note.
- Not in daily: add it to the `Related:` line of today's daily note.
- Duplicates: propose a merge (which note stays, what moves over); merging deletes a file, so do it only after a yes, and update links to the removed note.
- While a note is open for a fix, also add what the note format needs and is missing: `# Title`, tags, the up-link or `Related:` line.
- Every note whose body you changed goes into today's daily note too.

After fixing, run the script again, append one line `- <today> maintenance | <what changed>` to the log, and commit only the files you touched: `git -C <vault> add -- <paths>`, then `git -C <vault> commit -m "chore: vault maintenance"`. Leave unrelated uncommitted changes alone and mention them. Never push.
