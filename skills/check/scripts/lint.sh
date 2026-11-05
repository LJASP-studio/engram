#!/bin/sh
# lint.sh: mechanical health checks for an engram vault. POSIX sh + awk + git only.
#
# Usage: lint.sh VAULT [DATE_FIELD] [DAILY_FOLDER] [HUB] [LOG] [TODAY]
#   DATE_FIELD    frontmatter key holding the note date (default: date)
#   DAILY_FOLDER  folder of daily notes (default: Daily)
#   HUB, LOG      note names of the hub and the log, without .md (default: Home, Log)
#   TODAY         YYYY-MM-DD (default: today)
#
# Output: one finding per line, "CHECK<TAB>path<TAB>detail", then "SUMMARY<TAB>CHECK<TAB>count".
# Errors: MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE BROKEN_LINK ORPHAN NOT_IN_MOC
#         NOT_IN_DAILY
# Warnings: NO_MOC DUPLICATE_NAME LIKELY_DUPLICATE DAILY_CHECK_SKIPPED DAILY_CHECK_BY_DATE
# Exit status: 0 when there are no errors, 1 when there are, 2 on bad usage.

set -eu

if [ $# -lt 1 ] || [ ! -d "$1" ]; then
  echo "usage: lint.sh VAULT [DATE_FIELD] [DAILY_FOLDER] [HUB] [LOG] [TODAY]" >&2
  exit 2
fi

VAULT=$1
DATE_FIELD=${2:-date}
DAILY=${3:-Daily}
HUB=${4:-Home}
LOG=${5:-Log}
TODAY=${6:-$(date +%Y-%m-%d)}

cd "$VAULT"
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t engram)
trap 'rm -rf "$TMP"' EXIT INT TERM

# Every file (links may point at attachments or .base files) and every note.
find . \( -name .git -o -name .obsidian -o -name .trash -o -name node_modules \) -prune \
  -o -type f -print | sed 's|^\./||' | LC_ALL=C sort > "$TMP/all"
grep '\.md$' "$TMP/all" > "$TMP/notes" || :

# Body of a note: everything after the frontmatter block.
body() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm' "$@"
}

# Notes whose body changed today. Frontmatter-only edits (a bulk metadata pass) do not count.
: > "$TMP/today"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
   [ "$(git rev-parse --show-toplevel)" = "$(pwd -P)" ]; then
  base=$(git rev-list -1 --before="$TODAY 00:00" HEAD 2>/dev/null || :)
  if [ -n "$base" ]; then
    { git -c core.quotePath=false diff --name-only "$base" -- '*.md'
      git -c core.quotePath=false ls-files --others --exclude-standard -- '*.md'
    } | LC_ALL=C sort -u > "$TMP/changed"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      if git cat-file -e "$base:$f" 2>/dev/null; then
        git show "$base:$f" | body > "$TMP/old"
        body "$f" > "$TMP/new"
        cmp -s "$TMP/old" "$TMP/new" || printf '%s\n' "$f" >> "$TMP/today"
      else
        printf '%s\n' "$f" >> "$TMP/today"
      fi
    done < "$TMP/changed"
    echo "byBody" > "$TMP/todaymode"
  else
    echo "byDate" > "$TMP/todaymode"   # no commit before today: fall back to the date field
  fi
else
  echo "skip" > "$TMP/todaymode"
fi

LC_ALL=C awk \
  -v all="$TMP/all" -v notes="$TMP/notes" -v todayf="$TMP/today" -v modef="$TMP/todaymode" \
  -v datefield="$DATE_FIELD" -v daily="$DAILY" -v hub="$HUB.md" -v logf="$LOG.md" -v today="$TODAY" '
function base(p,   b) { b = p; sub(/.*\//, "", b); return b }
function dir(p,   d) { d = p; if (d !~ /\//) return "."; sub(/\/[^\/]*$/, "", d); return d }
function stem(p,   s) { s = base(p); sub(/\.md$/, "", s); return s }
function norm(s) {
  s = tolower(s)
  gsub(/\xc3\xa7|\xc3\x87/, "c", s); gsub(/\xc4\x9f|\xc4\x9e/, "g", s)
  gsub(/\xc4\xb1|\xc4\xb0/, "i", s); gsub(/\xc3\xb6|\xc3\x96/, "o", s)
  gsub(/\xc5\x9f|\xc5\x9e/, "s", s); gsub(/\xc3\xbc|\xc3\x9c/, "u", s)
  gsub(/\xc3\xa9|\xc3\xa8|\xc3\xaa/, "e", s); gsub(/\xc3\xa1|\xc3\xa0|\xc3\xa2/, "a", s)
  gsub(/\xc3\xad|\xc3\xae/, "i", s); gsub(/\xc3\xb3|\xc3\xb4/, "o", s)
  gsub(/\xc3\xba|\xc3\xbb/, "u", s); gsub(/\xc3\xb1/, "n", s)
  gsub(/[^a-z0-9]/, "", s)
  return s
}
function resolve(t,   l, b) {
  l = tolower(t); sub(/\.md$/, "", l)
  if (l in mdpath) return mdpath[l]
  b = l; sub(/.*\//, "", b)
  if (b in mdstem) return mdstem[b]
  l = tolower(t)
  if (l in anypath) return "@file"
  b = l; sub(/.*\//, "", b)
  if (b in anybase) return "@file"
  return ""
}
function report(check, path, detail) {
  printf "%s\t%s\t%s\n", check, path, detail
  count[check]++
}
function scan(f,   line, n, fm, code, raw, t, target, d, desc) {
  n = 0; fm = 0; code = 0; hasfm[f] = 0; hasdesc[f] = 0; hasdate[f] = 0; ismoc[f] = 0
  while ((getline line < f) > 0) {
    n++
    sub(/\r$/, "", line)
    if (n == 1 && line == "---") { fm = 1; hasfm[f] = 1; continue }
    if (fm) {
      if (line == "---") { fm = 0; continue }
      if (line ~ /^description:[ \t]*[^ \t]/) {
        hasdesc[f] = 1; desc = line; sub(/^description:[ \t]*/, "", desc); description[f] = desc
      }
      if (index(line, datefield ":") == 1) {
        d = substr(line, length(datefield) + 2); gsub(/[ \t"\047]/, "", d)
        if (d ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) { hasdate[f] = 1; notedate[f] = d }
      }
      if (line ~ /^tags:.*[\[ ,]moc[\], ]/ || line ~ /^tags:.*[\[ ,]moc$/ || line ~ /^  - moc$/) ismoc[f] = 1
      continue
    }
    if (line ~ /^[ \t]*(```|~~~)/) { code = !code; continue }
    if (code) continue
    gsub(/`[^`]*`/, "", line)
    while (match(line, /\[\[[^\]]+\]\]/)) {
      raw = substr(line, RSTART + 2, RLENGTH - 4)
      line = substr(line, RSTART + RLENGTH)
      t = raw
      sub(/\|.*/, "", t); sub(/#.*/, "", t); sub(/\\$/, "", t)
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == "") continue
      target = resolve(t)
      if (target == "") { report("BROKEN_LINK", f, "[[" raw "]]"); continue }
      if (target == "@file" || target == f) continue
      if (!((f, target) in linked)) { linked[f, target] = 1; inbound[target]++ }
    }
  }
  close(f)
}
BEGIN {
  while ((getline p < all) > 0) {
    anypath[tolower(p)] = 1; anybase[tolower(base(p))] = 1
    if (p ~ /\.md$/) {
      k = tolower(p); sub(/\.md$/, "", k); mdpath[k] = p
      s = tolower(stem(p))
      if (s in mdstem) report("DUPLICATE_NAME", p, "same name as " mdstem[s])
      else mdstem[s] = p
    }
  }
  close(all)
  n = 0
  while ((getline p < notes) > 0) note[++n] = p
  close(notes)
  for (i = 1; i <= n; i++) scan(note[i])

  for (i = 1; i <= n; i++) {
    f = note[i]
    if (!hasfm[f]) { report("MISSING_FRONTMATTER", f, ""); continue }
    if (!hasdesc[f]) report("MISSING_DESCRIPTION", f, "")
    if (!hasdate[f]) report("MISSING_DATE", f, datefield)
  }

  # Orphans: no other note links here. The hub is the entry point and is exempt.
  for (i = 1; i <= n; i++) {
    f = note[i]
    if (f == hub) continue
    if (!(f in inbound)) report("ORPHAN", f, "no inbound links")
  }

  # MOC coverage: a folder note is Folder/Folder.md or a sibling Folder.md next to the folder.
  for (i = 1; i <= n; i++) {
    f = note[i]; d = dir(f)
    if (d == ".") continue
    m1 = d "/" base(d) ".md"
    m2 = (dir(d) == "." ? "" : dir(d) "/") base(d) ".md"
    moc = ""
    k1 = tolower(m1); sub(/\.md$/, "", k1)
    k2 = tolower(m2); sub(/\.md$/, "", k2)
    if (k1 in mdpath) moc = mdpath[k1]
    else if (k2 in mdpath) moc = mdpath[k2]
    if (moc == "") { if (!(d in nomoc)) { nomoc[d] = 1; report("NO_MOC", d, "folder has no MOC note") } continue }
    if (moc == f) continue
    if (!((moc, f) in linked)) report("NOT_IN_MOC", f, moc)
  }

  # Likely duplicates: same normalised title in one folder (ignoring a date prefix),
  # or the same normalised description anywhere.
  for (i = 1; i <= n; i++) {
    f = note[i]; t = stem(f); sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] /, "", t)
    k = dir(f) SUBSEP norm(t)
    if (norm(t) != "" && k in seentitle) report("LIKELY_DUPLICATE", f, "title like " seentitle[k])
    else seentitle[k] = f
    if (f in description) {
      k = norm(description[f])
      if (length(k) > 20 && k in seendesc) report("LIKELY_DUPLICATE", f, "description like " seendesc[k])
      else seendesc[k] = f
    }
  }

  # Daily note coverage.
  getline mode < modef; close(modef)
  dailynote = daily "/" today ".md"
  if (mode == "skip") report("DAILY_CHECK_SKIPPED", ".", "vault is not the root of a git repository")
  else {
    if (mode == "byBody") { while ((getline f < todayf) > 0) touched[f] = 1; close(todayf) }
    else {
      report("DAILY_CHECK_BY_DATE", ".", "no commit before today: checked notes dated today, not body changes")
      for (i = 1; i <= n; i++) if (notedate[note[i]] == today) touched[note[i]] = 1
    }
    for (f in touched) {
      if (f == hub || f == logf || ismoc[f] || dir(f) == daily || index(f, daily "/") == 1) continue
      if (!((dailynote, f) in linked)) report("NOT_IN_DAILY", f, dailynote)
    }
  }

  errors = 0
  split("MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE BROKEN_LINK ORPHAN NOT_IN_MOC NOT_IN_DAILY NO_MOC DUPLICATE_NAME LIKELY_DUPLICATE DAILY_CHECK_SKIPPED DAILY_CHECK_BY_DATE", checks, " ")
  for (i = 1; i <= 12; i++) {
    printf "SUMMARY\t%s\t%d\n", checks[i], count[checks[i]] + 0
    if (i <= 7) errors += count[checks[i]]
  }
  printf "SUMMARY\tNOTES\t%d\n", n
  exit errors > 0 ? 1 : 0
}
' < /dev/null
