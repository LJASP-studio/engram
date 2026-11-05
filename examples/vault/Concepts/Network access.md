---
description: What talks to the network in each project: Inkwell's push-only sync client and tide-cli's planned tide-table reader.
date: 2026-11-05
source: [inkwell/src/sync/client.ts, tide-cli/README.md, tide-cli/internal/forecast/forecast.go]
code: [inkwell/src/sync/client.ts, tide-cli/internal/forecast/forecast.go]
tags: [concept]
---
# Network access

The code that leaves the machine. Start here before adding anything that calls a server, and keep the list current.

## Inkwell
- [[Inkwell sync client]]: optional; sends document revisions to a self-hosted server with HTTP PUT, push only.

## tide-cli
- [[forecast package]]: meant to read a public tide table and cache it for an hour; today it returns fixed times and sends no request.

Related: [[Home]]
