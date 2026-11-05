---
description: internal/forecast returns the next tides; table reading and the one-hour cache the changelog promises are not implemented yet.
date: 2026-02-20
source: [tide-cli/internal/forecast/forecast.go, tide-cli/CHANGELOG.md (1.0.0)]
code: [tide-cli/internal/forecast/forecast.go]
tags: [module]
---
# forecast package

`Next(harbour string) string` returns fixed times today. The package comment and the 1.0.0 changelog describe reading tide tables and caching them for an hour; start here when adding real data or the cache.

Related: [[tide-cli]] · [[tide command]] · [[Network access]]
