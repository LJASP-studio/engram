#!/bin/sh
# Tests for skills/check/scripts/lint.sh on a synthetic vault. POSIX sh; needs git.
# Usage: sh tests/run.sh

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LINT="$ROOT/skills/check/scripts/lint.sh"
WORK=$(mktemp -d 2>/dev/null || mktemp -d -t engram-test)
trap 'rm -rf "$WORK"' EXIT INT TERM
FAILS=0

note() { # note PATH CONTENT...
  mkdir -p "$WORK/v/$(dirname "$1")"
  p=$1; shift
  printf '%s\n' "$@" > "$WORK/v/$p"
}

expect() { # expect CHECK COUNT
  got=$(awk -F '\t' -v c="$1" '$1 == "SUMMARY" && $2 == c { print $3 }' "$WORK/out")
  if [ "$got" = "$2" ]; then echo "ok   $SCENARIO: $1 = $2"
  else echo "FAIL $SCENARIO: $1 expected $2, got ${got:-none}"; FAILS=$((FAILS + 1)); fi
}

expect_line() { # expect_line CHECK PATH
  if awk -F '\t' -v c="$1" -v p="$2" '$1 == c && $2 == p { found = 1 } END { exit !found }' "$WORK/out"
  then echo "ok   $SCENARIO: $1 $2"
  else echo "FAIL $SCENARIO: missing $1 $2"; FAILS=$((FAILS + 1)); fi
}

lint() { sh "$LINT" "$WORK/v" date Daily Home Log "$1" > "$WORK/out" || :; }

# A small vault for a made-up note-taking app, with one problem of each kind.
note Home.md '---' 'description: Entry point.' 'date: 2026-01-01' 'tags: [moc]' '---' '# Home' \
  '- [[Projects]]' '- [[Decisions]]' '- [[Daily]]' 'Changes: [[Log]]'
note Log.md '---' 'description: Change log.' 'date: 2026-01-01' '---' '# Log' '- 2026-01-01 setup | Vault created'
note Projects/Projects.md '---' 'description: Projects index.' 'date: 2026-01-01' 'tags: [moc]' '---' \
  '- [[Inkwell]]: a markdown editor'
note Projects/Inkwell/Inkwell.md '---' 'description: Inkwell hub.' 'date: 2026-01-02' '---' '# Inkwell' \
  '- [[Editor core|the editor]]' '- [[Sync service#Setup]]' '- [[Ghost note]]' '![[diagram.png]]'
note Projects/Inkwell/diagram.png 'not really a png'
note Projects/Inkwell/Editor\ core.md '---' 'description: The editing engine and its buffer model.' \
  'date: 2026-01-03' 'code: [inkwell/src/editor/]' '---' '# Editor core' 'Piece table.' \
  '```' 'example [[Not a link]]' '```' 'Inline `[[nope]]` is code.' 'Related: [[Inkwell]]'
note Projects/Inkwell/Sync\ service.md '---' 'date: 2026-01-04' '---' '# Sync service' 'Related: [[Inkwell]]'
note Projects/Inkwell/Export.md '---' 'description: Export to PDF and HTML.' '---' '# Export' 'Related: [[Inkwell]]'
note Decisions/Decisions.md '---' 'description: Decisions index.' 'date: 2026-01-01' 'tags: [moc]' '---' \
  '- [[2026-01-10 Use SQLite]]: local storage'
note "Decisions/2026-01-10 Use SQLite.md" '---' 'description: Local storage is SQLite, one file per vault.' \
  'date: 2026-01-10' '---' 'Uses [[SQLite]].'
note "Decisions/2026-02-01 Use SQLite.md" '---' 'description: SQLite for storage again, written twice.' \
  'date: 2026-02-01' '---' 'Uses [[SQLite]].'
note Tech/SQLite.md '---' 'description: Embedded database.' 'date: 2026-01-10' '---' 'See [[Raw]].'
note Tech/Raw.md '# Raw' 'No frontmatter here.'
note Daily/Daily.md '---' 'description: Daily index.' 'date: 2026-01-01' 'tags: [moc]' '---' '- [[2026-03-01]]'
note Daily/2026-03-01.md '---' 'description: What happened on 2026-03-01.' 'date: 2026-03-01' 'tags: [daily]' '---' \
  'Related: [[Inkwell]]'

SCENARIO=plain
lint 2026-03-01
expect MISSING_FRONTMATTER 1
expect MISSING_DESCRIPTION 1
expect MISSING_DATE 1
expect BROKEN_LINK 1
expect ORPHAN 2
expect NOT_IN_MOC 2
expect NO_MOC 1
expect LIKELY_DUPLICATE 1
expect DUPLICATE_NAME 0
expect DAILY_CHECK_SKIPPED 1
expect_line BROKEN_LINK Projects/Inkwell/Inkwell.md
expect_line ORPHAN Projects/Inkwell/Export.md
expect_line MISSING_FRONTMATTER Tech/Raw.md

# Daily coverage: commit "yesterday", then change one body, one frontmatter only, and add a note.
SCENARIO=daily
(
  cd "$WORK/v"
  git init -q
  git add -A
  GIT_AUTHOR_DATE="2026-02-28T12:00:00" GIT_COMMITTER_DATE="2026-02-28T12:00:00" \
    git -c user.name=test -c user.email=test@example.invalid commit -q -m init
)
printf 'More about the buffer.\n' >> "$WORK/v/Projects/Inkwell/Editor core.md"
sed 's/^description: Inkwell hub\./description: Inkwell, the editor app hub./' \
  "$WORK/v/Projects/Inkwell/Inkwell.md" > "$WORK/tmp" && mv "$WORK/tmp" "$WORK/v/Projects/Inkwell/Inkwell.md"
note Projects/Inkwell/Search.md '---' 'description: Full-text search.' 'date: 2026-03-01' '---' 'Related: [[Inkwell]]'
lint 2026-03-01
expect NOT_IN_DAILY 2
expect_line NOT_IN_DAILY "Projects/Inkwell/Editor core.md"
expect_line NOT_IN_DAILY Projects/Inkwell/Search.md
expect DAILY_CHECK_SKIPPED 0
expect DAILY_CHECK_BY_DATE 0

# The example vault shipped in examples/ must stay clean.
SCENARIO=example
sh "$LINT" "$ROOT/examples/vault" date Daily Home Log 2026-11-05 > "$WORK/out" || :
for c in MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE BROKEN_LINK ORPHAN NOT_IN_MOC NO_MOC LIKELY_DUPLICATE; do expect $c 0; done

if [ "$FAILS" -eq 0 ]; then echo "all tests passed"; else echo "$FAILS failed"; exit 1; fi
