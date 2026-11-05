---
description: CLI entry point cmd/tide/main.go; takes a harbour, prints the next tides, or prints usage and exits with status 2.
date: 2026-02-20
source: [tide-cli/cmd/tide/main.go, tide-cli/CHANGELOG.md (1.0.0)]
code: [tide-cli/cmd/tide/main.go]
tags: [module]
---
# tide command

Without an argument it writes `usage: tide <harbour>` to stderr and exits with 2; with one it prints `forecast.Next(harbour)`. Listed in [[tide-cli 1.0.0]].

Related: [[tide-cli]] · [[forecast package]]
