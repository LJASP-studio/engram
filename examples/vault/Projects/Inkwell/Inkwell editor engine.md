---
description: Piece-table buffer in src/editor/buffer.ts; insert takes no position so text can only be appended, there is no delete, and undo history is not in the code yet.
date: 2026-01-12
source: [inkwell/src/editor/buffer.ts, inkwell/CHANGELOG.md (0.1.0), conversation 2026-11-05]
code: [inkwell/src/editor/buffer.ts]
tags: [module]
---
# Inkwell editor engine

`PieceTable` keeps the original text and an append-only add buffer and rebuilds the document in `toString()`. `insert(text)` takes no position argument: each call pushes a new piece at the end, so text can only be appended, never inserted in the middle. There is no delete method either, so nothing can be removed (confirmed in a code review on 2026-11-05). The README and the 0.2.0 changelog mention undo history, but `src/editor/` holds only `buffer.ts`. Shipped in [[Inkwell 0.1.0]].

Related: [[Inkwell]] · [[Inkwell 0.2.0]]
