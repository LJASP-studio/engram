#!/bin/sh
# Tests for skills/check/scripts/lint.sh, skills/scan/scripts/edited.sh and hooks/live.sh on synthetic vaults.
# POSIX sh; needs git. Usage: sh tests/run.sh

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LINT="$ROOT/skills/check/scripts/lint.sh"
EDITED="$ROOT/skills/scan/scripts/edited.sh"
LIVE="$ROOT/hooks/live.sh"
WORK=$(mktemp -d 2>/dev/null || mktemp -d -t engram-test)
trap 'rm -rf "$WORK"' EXIT INT TERM
FAILS=0
V="$WORK/v"

note() { # note PATH CONTENT... (relative to $V)
  mkdir -p "$V/$(dirname "$1")"
  p=$1; shift
  printf '%s\n' "$@" > "$V/$p"
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

expect_out() { # expect_out LINE...: the exact lines of $WORK/out, in order
  printf '%s\n' "$@" > "$WORK/want"
  if cmp -s "$WORK/want" "$WORK/out"; then echo "ok   $SCENARIO: $(tr '\n' ' ' < "$WORK/want")"
  else echo "FAIL $SCENARIO: expected [$(tr '\n' ' ' < "$WORK/want")] got [$(tr '\n' ' ' < "$WORK/out")]"; FAILS=$((FAILS + 1)); fi
}

lint() { sh "$LINT" "$V" date Daily Home Log "$1" > "$WORK/out" || :; }

commit_at() { # commit_at DIR DATE MESSAGE: commit everything in DIR at a fixed time
  ( cd "$1" && git add -A &&
    GIT_AUTHOR_DATE="$2T12:00:00" GIT_COMMITTER_DATE="$2T12:00:00" \
      git -c user.name=test -c user.email=test@example.invalid commit -q -m "$3" )
}

# 1. A small vault for a made-up note-taking app, with one problem of each kind. No .engram.json.
note Home.md '---' 'description: Entry point.' 'date: 2026-01-01' 'tags: [moc]' '---' '# Home' \
  '- [[Projects]]' '- [[Decisions]]' '- [[Daily]]' 'Changes: [[Log]]'
note Log.md '---' 'description: Change log.' 'date: 2026-01-01' '---' '# Log' '- 2026-01-01 setup | Vault created'
note Projects/Projects.md '---' 'description: Projects index.' 'date: 2026-01-01' 'tags: [moc]' '---' \
  '- [[Inkwell]]: a markdown editor'
note Projects/Inkwell/Inkwell.md '---' 'description: Inkwell hub.' 'date: 2026-01-02' 'source: inkwell/README.md' '---' \
  '# Inkwell' '- [[Editor core|the editor]]' '- [[Sync service#Setup]]' '- [[Ghost note]]' '![[diagram.png]]'
note Projects/Inkwell/diagram.png 'not really a png'
note Projects/Inkwell/Editor\ core.md '---' 'description: The editing engine and its buffer model.' \
  'date: 2026-01-03' 'code: [inkwell/src/editor/]' '---' '# Editor core' 'Piece table.' \
  '```' 'example [[Not a link]]' '```' 'Inline `[[nope]]` is code.' 'Related: [[Inkwell]]'
note Projects/Inkwell/Sync\ service.md '---' 'date: 2026-01-04' 'source:' '  - inkwell/src/sync/' '---' \
  '# Sync service' 'Related: [[Inkwell]]'
note Projects/Inkwell/Export.md '---' 'description: Export to PDF and HTML.' 'source: [inkwell/README.md]' '---' \
  '# Export' 'Related: [[Inkwell]]'
note Decisions/Decisions.md '---' 'description: Decisions index.' 'date: 2026-01-01' 'tags: [moc]' '---' \
  '- [[2026-01-10 Use SQLite]]: local storage'
note "Decisions/2026-01-10 Use SQLite.md" '---' 'description: Local storage is SQLite, one file per vault.' \
  'date: 2026-01-10' 'source: [inkwell/docs/adr-1.md]' '---' 'Uses [[SQLite]].'
note "Decisions/2026-02-01 Use SQLite.md" '---' 'description: SQLite for storage again, written twice.' \
  'date: 2026-02-01' 'tags:' '  - decision' '---' 'Uses [[SQLite]].'
note Tech/SQLite.md '---' 'description: Embedded database.' 'date: 2026-01-10' 'source: https://sqlite.org' '---' 'See [[Raw]].'
note Tech/Raw.md '# Raw' 'No frontmatter here.'
note Daily/Daily.md '---' 'description: Daily index.' 'date: 2026-01-01' 'tags: [moc]' '---' '- [[2026-03-01]]'
note Daily/2026-03-01.md '---' 'description: What happened on 2026-03-01.' 'date: 2026-03-01' 'tags: [daily]' '---' \
  'Related: [[Inkwell]]'

SCENARIO=plain
lint 2026-03-01
expect MISSING_FRONTMATTER 1
expect MISSING_DESCRIPTION 1
expect MISSING_DATE 1
expect MISSING_SOURCE 2
expect BROKEN_LINK 1
expect ORPHAN 2
expect NOT_IN_MOC 2
expect NO_MOC 1
expect LIKELY_DUPLICATE 1
expect DUPLICATE_NAME 0
expect DAILY_CHECK_SKIPPED 1
expect CODE_PATH_MISSING 0
expect PRIVACY_UNSET 0
expect_line BROKEN_LINK Projects/Inkwell/Inkwell.md
expect_line ORPHAN Projects/Inkwell/Export.md
expect_line MISSING_FRONTMATTER Tech/Raw.md
expect_line MISSING_SOURCE "Projects/Inkwell/Editor core.md"
expect_line MISSING_SOURCE "Decisions/2026-02-01 Use SQLite.md"

# 2. Daily coverage: commit "yesterday", then change one body, one frontmatter only, and add a note.
SCENARIO=daily
( cd "$V" && git init -q )
commit_at "$V" 2026-02-28 init
printf 'More about the buffer.\n' >> "$V/Projects/Inkwell/Editor core.md"
sed 's/^description: Inkwell hub\./description: Inkwell, the editor app hub./' \
  "$V/Projects/Inkwell/Inkwell.md" > "$WORK/tmp" && mv "$WORK/tmp" "$V/Projects/Inkwell/Inkwell.md"
note Projects/Inkwell/Search.md '---' 'description: Full-text search.' 'date: 2026-03-01' '---' 'Related: [[Inkwell]]'
lint 2026-03-01
expect NOT_IN_DAILY 2
expect_line NOT_IN_DAILY "Projects/Inkwell/Editor core.md"
expect_line NOT_IN_DAILY Projects/Inkwell/Search.md
expect DAILY_CHECK_SKIPPED 0
expect DAILY_CHECK_BY_DATE 0

# 3. A workspace with .engram.json: a git project scanned at a known commit, a project set to
#    none, read-deny rules, code paths, decisions inferred from commits and a pending proposal.
SCENARIO=workspace
WS="$WORK/ws"; V="$WS/brain"
mkdir -p "$WS/app/src" "$WS/app/docs" "$WS/secret" "$WS/.claude"
printf 'a\n' > "$WS/app/src/a.ts"; printf 'b\n' > "$WS/app/src/b.ts"; printf 'docs\n' > "$WS/app/docs/guide.md"
printf 'plan\n' > "$WS/secret/plan.md"
( cd "$WS/app" && git init -q )
commit_at "$WS/app" 2026-01-01 "feat: first version"
SCANNED=$(git -C "$WS/app" rev-parse --short HEAD)
printf '%s\n' '{ "permissions": { "deny": [ "Read(./**/.env)", "Read(/secret/**)", "Read(/app/**)" ] } }' \
  > "$WS/.claude/settings.json"
note .engram.json '{' '  "version": 1,' '  "language": "en",' '  "projectsRoot": "..",' \
  '  "folders": { "projects": "Projects", "decisions": "Decisions", "daily": "Daily" },' \
  "  \"lastScan\": { \"app\": { \"commit\": \"$SCANNED\", \"date\": \"2026-01-01\" } }," \
  '  "privacy": {' '    "projects": { "app": "full", "secret": "none" },' \
  '    "exclude": [".env", "*.pem"]' '  }' '}'
note Home.md '---' 'description: Entry point.' 'date: 2026-01-02' 'tags: [moc]' '---' \
  '- [[Projects]] · [[Decisions]] · [[Daily]] · [[Log]]'
note Log.md '---' 'description: Change log.' 'date: 2026-01-02' '---' 'Back to [[Home]].'
note Daily/Daily.md '---' 'description: Daily index.' 'date: 2026-01-02' 'tags: [moc]' '---' 'Up: [[Home]]'
note Projects/Projects.md '---' 'description: Projects index.' 'date: 2026-01-02' 'tags: [moc]' '---' '- [[App]]'
note Projects/App/App.md '---' 'description: The app hub.' 'date: 2026-01-02' 'source: [app/docs/guide.md]' \
  'code: [app/src/]' 'tags: [project]' '---' '- [[Guide]] · [[Old module]] · [[Secret plan]] · [[Decisions]]'
note Projects/App/Guide.md '---' 'description: The user guide.' 'date: 2026-01-02' 'source: [app/docs/guide.md]' \
  'code: [app/docs/guide.md]' '---' 'Up: [[App]]'
note "Projects/App/Old module.md" '---' 'description: A module that was removed.' 'date: 2026-01-02' \
  'source: [app/docs/guide.md]' 'code:' '  - app/src/gone.ts' '  - app/src/b.ts' '---' 'Up: [[App]]'
note "Projects/App/Secret plan.md" '---' 'description: Should not exist.' 'date: 2026-01-02' \
  'source: [secret/plan.md]' '---' 'Up: [[App]]'
note Decisions/Decisions.md '---' 'description: Decisions index.' 'date: 2026-01-02' 'tags: [moc]' '---' \
  '- [[2026-01-01 Tabs]] · [[2026-01-01 Spaces]] · [[App]]'
note "Decisions/2026-01-01 Tabs.md" '---' 'description: Tabs, inferred from a commit.' 'date: 2026-01-01' \
  "source: [app@$SCANNED]" 'tags: [decision]' '---' 'Up: [[Decisions]]'
note "Decisions/2026-01-01 Spaces.md" '---' 'description: Spaces, inferred and marked.' 'date: 2026-01-01' \
  "source: [\"app@$SCANNED\"]" 'confidence: inferred' 'tags: [decision]' '---' 'Up: [[Decisions]]'
note Proposals/App.proposal.md '---' 'description: Proposed update to App.' 'date: 2026-01-02' \
  'tags: [proposal]' '---' '```markdown' '[[Nowhere]]' '```'
( cd "$V" && git init -q )
commit_at "$V" 2026-01-02 "docs: scan app"
printf 'a2\n' > "$WS/app/src/a.ts"
commit_at "$WS/app" 2026-01-03 "fix: change a"
lint 2026-01-04
expect CODE_PATH_MISSING 1
expect_line CODE_PATH_MISSING "Projects/App/Old module.md"
expect STALE 1
expect_line STALE Projects/App/App.md
expect INFERRED_UNMARKED 1
expect_line INFERRED_UNMARKED "Decisions/2026-01-01 Tabs.md"
expect INFERRED 1
expect PROPOSAL_PENDING 1
expect PRIVACY_MISMATCH 2
expect_line PRIVACY_MISMATCH app
expect_line PRIVACY_MISMATCH "*.pem"
expect PRIVACY_NONE_NOTES 1
expect_line PRIVACY_NONE_NOTES "Projects/App/Secret plan.md"
expect PRIVACY_UNSET 0
expect BROKEN_LINK 0
expect ORPHAN 0
expect DUPLICATE_NAME 0

# 4. edited.sh: which notes carry the user's own edits.
SCENARIO=edited
printf 'My own line.\n' >> "$V/Projects/App/Guide.md"
commit_at "$V" 2026-01-05 "chore: snapshot manual edits"
( cd "$V" && git mv Projects/App/Guide.md Projects/App/Handbook.md )
commit_at "$V" 2026-01-06 "docs: rename Guide to Handbook"
note Projects/App/Mine.md '---' 'description: Written in Obsidian.' '---'
commit_at "$V" 2026-01-07 "vault backup"
printf 'Typed today.\n' >> "$V/Projects/App/App.md"
note Projects/App/Draft.md 'not committed yet'
sh "$EDITED" "$V" > "$WORK/out"
expect_out Projects/App/App.md Projects/App/Draft.md Projects/App/Handbook.md Projects/App/Mine.md
sh "$EDITED" "$V" "Projects/App/Old module.md" "$V/Projects/App/Handbook.md" ./Projects/App/Mine.md > "$WORK/out"
expect_out Projects/App/Handbook.md Projects/App/Mine.md
if sh "$EDITED" "$V" Projects/App/Nope.md > "$WORK/out" 2>/dev/null; then
  echo "FAIL $SCENARIO: an unknown note should exit 2"; FAILS=$((FAILS + 1))
else echo "ok   $SCENARIO: an unknown note exits 2"; fi
commit_at "$V" 2026-01-08 "chore: snapshot manual edits"
note Projects/App/Merged.md '---' 'description: Gets a merge.' '---'
note Projects/App/Clean.md '---' 'description: Untouched.' '---'
commit_at "$V" 2026-01-09 "docs: add Merged and Clean"
printf 'Lines from Draft.\n' >> "$V/Projects/App/Merged.md"
( cd "$V" && git rm -q Projects/App/Draft.md )
commit_at "$V" 2026-01-10 "docs: merge Draft into Merged"
sh "$EDITED" "$V" Projects/App/Merged.md Projects/App/Clean.md > "$WORK/out"
expect_out Projects/App/Merged.md

# 5. lint edge cases: unindented YAML lists, a none folder whose name has a space, a wrong root.
SCENARIO=edge
mkdir -p "$WS/my app/src"; printf 'x\n' > "$WS/my app/src/x.ts"
( cd "$WS/my app" && git init -q ); commit_at "$WS/my app" 2026-01-01 "feat: x"
MYAPP=$(git -C "$WS/my app" rev-parse --short HEAD)
sed "s/\"app\": { \"commit\"/\"my app\": { \"commit\": \"$MYAPP\", \"date\": \"2026-01-01\" }, \"app\": { \"commit\"/; s/\"secret\": \"none\"/\"secret\": \"none\", \"my app\": \"none\"/" \
  "$V/.engram.json" > "$WORK/tmp" && mv "$WORK/tmp" "$V/.engram.json"
note Projects/App/Listed.md '---' 'description: Lists without indent.' 'date: 2026-01-11' 'source:' '- app/docs/guide.md' \
  'code:' '- app/src/missing.ts' '---' 'Up: [[App]]'
commit_at "$V" 2026-01-11 "docs: add Listed"
printf 'x2\n' > "$WS/my app/src/x.ts"; commit_at "$WS/my app" 2026-01-12 "fix: x"
lint 2026-01-12
expect_line CODE_PATH_MISSING Projects/App/Listed.md
if grep -q '^STALE.*my app' "$WORK/out"; then echo "FAIL $SCENARIO: lint looked inside a none folder"; FAILS=$((FAILS + 1))
else echo "ok   $SCENARIO: nothing from a none folder"; fi
expect PROJECTS_ROOT_MISSING 0
sed 's/"projectsRoot": ".."/"projectsRoot": "..\/nowhere"/' "$V/.engram.json" > "$WORK/tmp" && mv "$WORK/tmp" "$V/.engram.json"
lint 2026-01-12
expect PROJECTS_ROOT_MISSING 1
if grep -q "MISSING_SOURCE	Projects/App/Listed.md" "$WORK/out"; then echo "FAIL $SCENARIO: unindented source list not read"; FAILS=$((FAILS + 1))
else echo "ok   $SCENARIO: unindented source list read"; fi

# 6. The example vault shipped in examples/ must stay clean.
SCENARIO=example
sh "$LINT" "$ROOT/examples/vault" date Daily Home Log 2026-11-05 > "$WORK/out" || :
for c in MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE MISSING_SOURCE BROKEN_LINK ORPHAN NOT_IN_MOC \
         CODE_PATH_MISSING NO_MOC LIKELY_DUPLICATE INFERRED_UNMARKED PRIVACY_UNSET PRIVACY_MISMATCH; do
  expect $c 0
done

# 7. Live graph hook: one line per note read or written inside a vault whose plugin is on.
SCENARIO=live
L="$WORK/live"
LOG="$L/notes/.obsidian/plugins/engram-live/live.jsonl"
mkdir -p "$L/notes/Projects" "$L/notes-old" "$L/app/src"
hook() { # hook PROJECT_DIR JSON
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" sh "$LIVE"
}
read_json() { printf '{"session_id":"s1","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$L" "$1" "$2"; }
hook "$L" "$(read_json Read "$L/notes/Home.md")"
if [ -e "$LOG" ]; then echo "FAIL $SCENARIO: wrote without the plugin's file"; FAILS=$((FAILS + 1))
else echo "ok   $SCENARIO: nothing without the plugin's file"; fi
mkdir -p "$(dirname "$LOG")"; : > "$LOG"
hook "$L" "$(read_json Read "$L/notes/Home.md")"
hook "$L/app/src" "$(read_json Edit "$L/notes/Projects/App.md")"
hook "$L" "$(read_json Write "$L/notes/./Projects/../Projects/New.md")"
hook "$L" '{"cwd":"'"$L"'","tool_name":"Read","tool_input":{"file_path":"notes/Rel.md"}}'
hook "$L" '{"tool_name":"Read","tool_input":{"file_path":"'"$L"'/notes/Projects/Çay \"ölçümü\".md"},"tool_response":{"file":{"content":"\"file_path\":\"x\""}}}'
hook "$L" '{"tool_name":"Grep","tool_input":{"pattern":"x","path":"'"$L"'/notes"}}'
hook "$L" "$(read_json Read "$L/app/src/x.ts")"
hook "$L" "$(read_json Read "$L/notes-old/Home.md")"
hook "$L" "$(read_json Read "$L/notes/.obsidian/graph.json")"
hook "$L/app" '{"session_id":"s2","hook_event_name":"Stop","stop_hook_active":false}'
cp "$LOG" "$WORK/out"
expect_out '{"v":1,"tool":"Read","path":"Home.md","session":"s1"}' '{"v":1,"tool":"Edit","path":"Projects/App.md","session":"s1"}' \
  '{"v":1,"tool":"Write","path":"Projects/New.md","session":"s1"}' '{"v":1,"tool":"Read","path":"Rel.md","session":""}' \
  '{"v":1,"tool":"Read","path":"Projects/Çay \"ölçümü\".md","session":""}' '{"v":1,"event":"stop","session":"s2"}'
: > "$LOG"
hook "$L" '{"session_id":"s3","cwd":"'"$L"'","tool_name":"Grep","tool_input":{"pattern":"^description:","path":"notes","output_mode":"content","-A":2},"tool_response":{"mode":"content","filenames":[],"content":"notes/Home.md:2:description: Entry.\nnotes/Home.md-3-date: x\n--\nnotes/Projects/App.md:2:description: An app.\napp/src/x.ts:1:description"}}'
hook "$L" '{"session_id":"s3","cwd":"'"$L"'","tool_name":"Grep","tool_input":{"pattern":"x","path":"notes"},"tool_response":{"mode":"files_with_matches","filenames":["notes/Projects/New.md","'"$L"'/notes/Rel.md","notes/.obsidian/x.md"]}}'
hook "$L/app" '{"session_id":"s3","cwd":"'"$L"'","tool_name":"Bash","tool_input":{"command":"grep -rn x notes"},"tool_response":{"stdout":"'"$L"'/notes/Projects/App.md:4:x\nnotes/Home.md\nnot a path\n","stderr":""}}'
cp "$LOG" "$WORK/out"
expect_out '{"v":1,"tool":"Grep","path":"Home.md","session":"s3"}' '{"v":1,"tool":"Grep","path":"Projects/App.md","session":"s3"}' \
  '{"v":1,"tool":"Grep","path":"Projects/New.md","session":"s3"}' '{"v":1,"tool":"Grep","path":"Rel.md","session":"s3"}' \
  '{"v":1,"tool":"Bash","path":"Projects/App.md","session":"s3"}' '{"v":1,"tool":"Bash","path":"Home.md","session":"s3"}'
head -c 1100000 /dev/zero | tr '\0' 'x' > "$LOG"
hook "$L" "$(read_json Read "$L/notes/Home.md")"
if [ "$(wc -c < "$LOG" | tr -d ' ')" -eq 1100000 ]; then echo "ok   $SCENARIO: no appending past 1 MB"
else echo "FAIL $SCENARIO: appended past 1 MB"; FAILS=$((FAILS + 1)); fi

if [ "$FAILS" -eq 0 ]; then echo "all tests passed"; else echo "$FAILS failed"; exit 1; fi
