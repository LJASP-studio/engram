---
description: Index of tool and framework notes, each shared by every project that uses it.
date: 2026-11-05
tags: [moc]
---
# Tech

One note per tool or framework, linked to the projects that use it.

- [[Go]]: Language of tide-cli; a Go 1.23 module with no third-party dependencies and the cmd/ and internal/ layout.
- [[React]]: UI library; Inkwell declares React 19 for its editor UI, though no components exist yet.
- [[SQLite]]: Embedded database; Inkwell stores documents and undo history in one SQLite file per vault through better-sqlite3.
- [[TypeScript]]: Language of Inkwell; the editor engine and the sync client are TypeScript modules under src/.
- [[Vite]]: Dev server and build tool behind Inkwell's npm run dev and npm run build; no config file, defaults only.
- [[Vitest]]: Test runner behind Inkwell's npm test (vitest run); no test files yet.

Up: [[Home]]
