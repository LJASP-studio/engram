# Changelog

## 0.4.1 - 2026-11-05

- Live graph shows searches too: notes whose lines a search returned (the Grep tool, or grep and rg run in Bash) glow faintly in their own color, notes Claude opens glow bright, and the counter adds how many notes matched. With description-first routing many questions are answered from the description lines alone, so before this the graph often stayed dark. The hook now also runs after Grep and Bash; it reads only the paths at the start of the output lines, never the text, and still writes nothing outside the vault. Glob is not shown. A setting turns search matches off.

## 0.4.0 - 2026-11-05

- Live graph: an Obsidian plugin (`obsidian/engram-live/`) that shows Claude's work on the vault in the graph view. A note Claude reads lights up in one color, an edited or new note in another; lit notes glow while Claude works, sparks run along their links, the other notes dim, and a counter shows notes read out of all notes. When Claude finishes its turn, everything fades out slowly.
- The plugin gets its events from a new hook in this plugin (`hooks/hooks.json`, `hooks/live.sh`): after Read, Edit and Write, and when a turn stops, it appends one line (tool, path inside the vault, session id) to `live.jsonl` in the Obsidian plugin's folder. The hook runs in the background, prints nothing and does nothing unless that file exists, which the Obsidian plugin creates only while it is enabled. No network, no file contents, no paths outside the vault; it stops appending past 1 MB.
- `/engram:setup live` copies the Obsidian plugin into the vault.

## 0.3.0 - 2026-11-05

- Privacy per machine: `setup` asks for each project folder whether its contents may be read (`full`), only its file names (`structure`, notes marked `visibility: internal`) or nothing (`none`), plus file patterns never read anywhere (`.env`, keys, certificates, credentials). Stored in `.engram.json` under `privacy` and written as `Read` deny rules into the projects folder's `.claude/settings.json`. `/engram:setup privacy` changes both; `scan` asks about new folders before reading them.
- Your edits are protected: before writing, every skill commits pending vault changes as `chore: snapshot manual edits`, and git history tells the user's edits from engram's. On a note the user edited, engram only adds lines; anything else becomes a proposal in `Proposals/` that the user applies or drops. New helper `skills/scan/scripts/edited.sh` lists those notes.
- `scan` shows a plan (new notes, updates, proposals, status notes, inferred decisions) and writes nothing before the user's OK.
- Status note per project (now, next, open questions, tried and did not work): `scan` creates it from a status file or an `Unreleased` changelog section only, `note` adds the outcome of each task.
- Decisions whose only sources are commits or tags carry `confidence: inferred` until the user confirms them.
- New checks: `MISSING_SOURCE`, `CODE_PATH_MISSING` and `PROJECTS_ROOT_MISSING` (errors), `STALE` (code under a note changed since the project's last scan and since the note was written), `INFERRED_UNMARKED`, `PROPOSAL_PENDING`, `PRIVACY_UNSET`, `PRIVACY_MISMATCH`, `PRIVACY_NONE_NOTES` (warnings), and an `INFERRED` count. `lint.sh` now reads `.engram.json`.
- Notes may be renamed, moved and merged when every link is updated in the same step, each change is its own commit and the check is clean afterwards; a merge that removes a file asks first.
- README: employer policy before sending work code to an LLM, no vault in iCloud Drive on Windows, pause file sync during bulk writes.

## 0.2.0 - 2026-11-05

- Concept notes: a `Concepts` folder for themes that notes in two or more projects share (security, privacy, determinism, localisation). Conventions, layout, hub templates, graph preset and the example vault have it; `scan` writes concept notes after the merge and `note` adds new notes to them.
- `scan` splits a large project into two briefs (documents and code map; history, decisions and data) so a subagent does not run out of context.
- Routing block and retrieval order are description-first: grep `^description:` with the `code:` lines, and read the hub and folder indexes only for broad questions. Measured on a real workspace (13 questions, two runs per question and order, against the same workspace without a vault), the old hub-first order used 18 percent fewer tokens and was cheaper on only 5 of 13 questions; description-first used 46 percent fewer tokens, 54 percent lower cost and 7 turns instead of 10, cheaper on 11 of 13.
- Scan brief: related notes go in `links:` only, and a hub update carries only its lead text, so merged hubs do not get a second content list.

## 0.1.0 - 2026-11-05

- First version of the `engram` plugin: `setup` (set up a vault), `scan` (scan projects), `note` (write a note), `check` (health check).
- `reference/conventions.md`: note format, vault layout, retrieval order, writing rules, types.
- `skills/check/scripts/lint.sh`: POSIX sh checks for missing fields, broken links, orphans, index and daily-note coverage, likely duplicates; tests in `tests/run.sh`.
- English vault structure with note text in English or Turkish; Obsidian graph preset and Bases views.
- Synthetic example projects and the vault built from them.
