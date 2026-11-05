---
description: Desktop Markdown editor in TypeScript with React, SQLite storage and optional self-hosted sync; how to run, test and where the code is.
date: 2026-02-03
source: [inkwell/README.md, inkwell/package.json, inkwell/CHANGELOG.md]
code: [inkwell/src/editor/, inkwell/src/sync/, inkwell/docs/decisions/, inkwell/package.json]
tags: [project]
---
# Inkwell

A small Markdown editor for the desktop, at version 0.2.0. Stack: [[TypeScript]], [[React]], [[SQLite]] through better-sqlite3, [[Vite]] and [[Vitest]]. Run with `npm install` and `npm run dev`; test with `npm test`.

## Code map
- [[Inkwell editor engine]]: Piece-table buffer in src/editor/buffer.ts; insert takes no position so text can only be appended, there is no delete, and undo history is not in the code yet.
- [[Inkwell sync client]]: `src/sync/`, pushes revisions to a self-hosted server.
- Decisions in `docs/decisions/`: [[2026-01-10 Store Inkwell documents in SQLite]].

No app entry file, storage module or tests exist yet.

Releases: [[Inkwell 0.1.0]] · [[Inkwell 0.2.0]]

Status: [[Inkwell status]]

Up: [[Projects]]
