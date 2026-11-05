---
description: Optional sync client in src/sync/client.ts that PUTs document revisions to a self-hosted server; push only, no pull or conflict handling.
date: 2026-02-03
source: [inkwell/src/sync/client.ts, inkwell/CHANGELOG.md (0.2.0)]
code: [inkwell/src/sync/client.ts]
tags: [module]
---
# Inkwell sync client

`pushRevision(serverUrl, docId, body)` sends an HTTP PUT to `<server>/docs/<docId>`. There is no pull, no conflict handling and no response check. Added in [[Inkwell 0.2.0]].

Related: [[Inkwell]]
