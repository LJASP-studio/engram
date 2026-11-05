---
description: Go command-line tool that prints the next high and low tide for a harbour; how to run, test and where the code is.
date: 2026-02-20
source: [tide-cli/README.md, tide-cli/CHANGELOG.md, tide-cli/go.mod]
code: [tide-cli/cmd/tide/main.go, tide-cli/internal/forecast/, tide-cli/go.mod]
tags: [project]
---
# tide-cli

Prints tide times for a harbour. Written in [[Go]] 1.23 with the standard library only. Run with `go run ./cmd/tide <harbour>`; test with `go test ./...`.

## Code map
- [[tide command]]: `cmd/tide/main.go`, the entry point.
- [[forecast package]]: `internal/forecast/`, the tide lookup.

Releases: [[tide-cli 1.0.0]]

Up: [[Projects]]
