# Changelog

## 0.2.0 - 2026-11-05

- Concept notes: a `Concepts` folder for themes that notes in two or more projects share (security, privacy, determinism, localisation). Conventions, layout, hub templates, graph preset and the example vault have it; `scan` writes concept notes after the merge and `note` adds new notes to them.
- `scan` splits a large project into two briefs (documents and code map; history, decisions and data) so a subagent does not run out of context.
- Scan brief: related notes go in `links:` only, and a hub update carries only its lead text, so merged hubs do not get a second content list.

## 0.1.0 - 2026-11-05

- First version of the `engram` plugin: `setup` (set up a vault), `scan` (scan projects), `note` (write a note), `check` (health check).
- `reference/conventions.md`: note format, vault layout, retrieval order, writing rules, types.
- `skills/check/scripts/lint.sh`: POSIX sh checks for missing fields, broken links, orphans, index and daily-note coverage, likely duplicates; tests in `tests/run.sh`.
- English vault structure with note text in English or Turkish; Obsidian graph preset and Bases views.
- Synthetic example projects and the vault built from them.
