# 1. Store documents in SQLite

Date: 2026-01-10

Documents and undo history live in one SQLite file per vault instead of loose files, so saves are atomic and search can use FTS5.
