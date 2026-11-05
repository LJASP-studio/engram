---
description: ADR 0001 keeps Inkwell documents and undo history in one SQLite file per vault, for atomic saves and FTS5 search.
date: 2026-01-10
source: inkwell/docs/decisions/0001-storage-sqlite.md
code: [inkwell/docs/decisions/0001-storage-sqlite.md]
tags: [decision]
---
# 2026-01-10 Store Inkwell documents in SQLite

Documents and undo history live in one [[SQLite]] file per vault instead of loose files. Reasons: atomic saves, and full-text search through FTS5. No storage code exists under `src/` yet.

Related: [[Inkwell]] · [[Inkwell 0.1.0]]
