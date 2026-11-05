#!/bin/sh
# lint.sh: mechanical health checks for an engram vault. POSIX sh + awk + git only.
#
# Usage: lint.sh VAULT [DATE_FIELD] [DAILY_FOLDER] [HUB] [LOG] [TODAY]
#   DATE_FIELD    frontmatter key holding the note date (default: date)
#   DAILY_FOLDER  folder of daily notes (default: Daily)
#   HUB, LOG      note names of the hub and the log, without .md (default: Home, Log)
#   TODAY         YYYY-MM-DD (default: today)
#
# Reads VAULT/.engram.json when it exists: projectsRoot, folders, lastScan and privacy.
# Without it the checks that need the projects (code paths, staleness, privacy) are skipped.
#
# Output: one finding per line, "CHECK<TAB>path<TAB>detail", then "SUMMARY<TAB>CHECK<TAB>count".
# Errors:   MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE MISSING_SOURCE BROKEN_LINK
#           ORPHAN NOT_IN_MOC NOT_IN_DAILY CODE_PATH_MISSING PROJECTS_ROOT_MISSING
# Warnings: NO_MOC DUPLICATE_NAME LIKELY_DUPLICATE STALE INFERRED_UNMARKED PROPOSAL_PENDING
#           PRIVACY_UNSET PRIVACY_MISMATCH PRIVACY_NONE_NOTES DAILY_CHECK_SKIPPED
#           DAILY_CHECK_BY_DATE
# Counts:   INFERRED (decisions waiting for confirmation), NOTES
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
TAB=$(printf '\t')

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

ISREPO=0
# The vault must be the root of its own repository. --show-prefix is empty only at the root,
# and unlike --show-toplevel it prints no drive letter on Windows (C:/ vs /c/).
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
   [ -z "$(git rev-parse --show-prefix 2>/dev/null)" ]; then
  ISREPO=1
fi

# Notes whose body changed today. Frontmatter-only edits (a bulk metadata pass) do not count.
: > "$TMP/today"
if [ "$ISREPO" = 1 ]; then
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

# .engram.json, flattened to one line per value: key<TAB>key...<TAB>value.
# Objects and arrays also get a line with the value {} or [], so empty ones are visible.
: > "$TMP/cfg"
if [ -f .engram.json ]; then
  awk '
  function emit(val,   d, p) {
    p = ""
    for (d = 1; d <= depth; d++) p = p (ctype[d] == "{" ? ckey[d] : cidx[d]) "\t"
    print p val
  }
  { s = s $0 "\n" }
  END {
    n = length(s); i = 1; depth = 0; expectkey = 0
    while (i <= n) {
      c = substr(s, i, 1)
      if (c == "{" || c == "[") {
        if (depth > 0) emit(c == "{" ? "{}" : "[]")
        depth++; ctype[depth] = c; cidx[depth] = 0; ckey[depth] = ""; expectkey = (c == "{"); i++; continue
      }
      if (c == "}" || c == "]") { depth--; expectkey = 0; i++; continue }
      if (c == ",") { if (ctype[depth] == "{") expectkey = 1; else cidx[depth]++; i++; continue }
      if (c == ":" || c == " " || c == "\t" || c == "\r" || c == "\n") { i++; continue }
      if (c == "\"") {
        str = ""; i++
        while (i <= n) {
          c = substr(s, i, 1)
          if (c == "\\") { str = str substr(s, i + 1, 1); i += 2; continue }
          if (c == "\"") break
          str = str c; i++
        }
        i++
        if (ctype[depth] == "{" && expectkey) { ckey[depth] = str; expectkey = 0 } else emit(str)
        continue
      }
      tok = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\r" || c == "\n") break
        tok = tok c; i++
      }
      emit(tok)
    }
  }' .engram.json > "$TMP/cfg"
fi

cfg() { # cfg KEY...: value at that key path, empty when absent
  awk -F "$TAB" -v k="$*" '
    BEGIN { n = split(k, want, " ") }
    NF == n + 1 { for (i = 1; i <= n; i++) if ($i != want[i]) next; print $NF; exit }' "$TMP/cfg"
}

# Projects root, staleness and privacy inputs. All of it needs .engram.json.
ROOTDIR=""
: > "$TMP/changes"; : > "$TMP/ntimes"; : > "$TMP/settings"
if [ -s "$TMP/cfg" ]; then
  root=$(cfg projectsRoot); root=${root:-..}
  ROOTDIR=$(cd "$root" 2>/dev/null && pwd -P || :)
fi
if [ -n "$ROOTDIR" ]; then
  [ -f "$ROOTDIR/.claude/settings.json" ] && cp "$ROOTDIR/.claude/settings.json" "$TMP/settings"

  # Files changed in each scanned git project since its lastScan commit, newest change first:
  # project<TAB>commit time<TAB>path relative to the project. A missing base commit gets "-".
  # Folders set to none are left out here, before any git command runs in them.
  awk -F "$TAB" '
    NF == 4 && $1 == "privacy" && $2 == "projects" && $4 == "none" { none[$3] = 1 }
    NF == 4 && $1 == "lastScan" && $3 == "commit" && $4 != "null" && $4 != "" { proj[++n] = $2; com[n] = $4 }
    END { for (i = 1; i <= n; i++) if (!(proj[i] in none)) print proj[i] "\t" com[i] }' "$TMP/cfg" > "$TMP/scanned"
  while IFS="$TAB" read -r proj commit; do
    dir="$ROOTDIR/$proj"
    if git -C "$dir" rev-parse --verify --quiet "$commit^{commit}" >/dev/null 2>&1; then
      git -C "$dir" -c core.quotePath=false log --relative --format=@%ct --name-only "$commit..HEAD" 2>/dev/null |
        awk -v p="$proj" '/^@/ { t = substr($0, 2); next } NF && !($0 in seen) { seen[$0] = 1; print p "\t" t "\t" $0 }'
    else
      printf '%s\t-\t%s\n' "$proj" "$commit"
    fi
  done < "$TMP/scanned" > "$TMP/changes"

  # When each note was last committed to the vault; uncommitted notes count as written now.
  if [ "$ISREPO" = 1 ]; then
    { git -c core.quotePath=false diff --name-only HEAD -- '*.md' 2>/dev/null |
        awk '{ print $0 "\t99999999999" }'
      git -c core.quotePath=false ls-files --others --exclude-standard -- '*.md' |
        awk '{ print $0 "\t99999999999" }'
      git -c core.quotePath=false log --format=@%ct --name-only -- '*.md' 2>/dev/null |
        awk '/^@/ { t = substr($0, 2); next } NF { print $0 "\t" t }'
    } | awk -F "$TAB" '!($1 in seen) { seen[$1] = 1; print }' > "$TMP/ntimes"
  fi
fi

ENGRAM_ROOT=$ROOTDIR ENGRAM_ROOT_SET=${root:-} ENGRAM_TMP=$TMP LC_ALL=C awk \
  -v all="$TMP/all" -v notes="$TMP/notes" -v todayf="$TMP/today" -v modef="$TMP/todaymode" \
  -v cfgf="$TMP/cfg" -v changesf="$TMP/changes" -v ntimesf="$TMP/ntimes" -v settingsf="$TMP/settings" \
  -v datefield="$DATE_FIELD" -v daily="$DAILY" -v hub="$HUB.md" -v logf="$LOG.md" -v today="$TODAY" '
function base(p,   b) { b = p; sub(/.*\//, "", b); return b }
function dir(p,   d) { d = p; if (d !~ /\//) return "."; sub(/\/[^\/]*$/, "", d); return d }
function top(p,   t) { t = p; sub(/\/.*/, "", t); return t }
function stem(p,   s) { s = base(p); sub(/\.md$/, "", s); return s }
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function unquote(s) {
  s = trim(s)
  if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2)
  return s
}
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
# Add the items of a frontmatter value (scalar or inline [list]) to list key of note f.
function additems(f, key, v,   i, c, q, item, n) {
  v = trim(v)
  if (v == "") return
  if (v !~ /^\[/) { additem(f, key, unquote(v)); return }
  v = substr(v, 2); sub(/\][ \t]*$/, "", v)
  item = ""; q = ""; n = length(v)
  for (i = 1; i <= n; i++) {
    c = substr(v, i, 1)
    if (q != "") { if (c == q) q = ""; item = item c; continue }
    if (c == "\"" || c == "\047") { q = c; item = item c; continue }
    if (c == ",") { additem(f, key, unquote(item)); item = ""; continue }
    item = item c
  }
  additem(f, key, unquote(item))
}
function additem(f, key, item) {
  if (item == "") return
  nitems[f, key]++
  items[f, key, nitems[f, key]] = item
  if (key == "tags") tag[f, item] = 1
}
function scan(f,   line, n, fm, code, raw, t, target, d, desc, k, v, cur) {
  n = 0; fm = 0; code = 0; cur = ""; hasfm[f] = 0; hasdesc[f] = 0; hasdate[f] = 0
  while ((getline line < f) > 0) {
    n++
    sub(/\r$/, "", line)
    if (n == 1 && line == "---") { fm = 1; hasfm[f] = 1; continue }
    if (fm) {
      if (line == "---") { fm = 0; continue }
      if (cur != "" && line ~ /^[ \t]*- /) { v = line; sub(/^[ \t]*- /, "", v); additem(f, cur, unquote(v)); continue }
      cur = ""
      if (line !~ /^[A-Za-z_][A-Za-z0-9_-]*:/) continue
      k = line; sub(/:.*/, "", k)
      v = line; sub(/^[^:]*:/, "", v); v = trim(v)
      if (k == "description" && v != "") { hasdesc[f] = 1; description[f] = v }
      if (k == datefield) {
        d = v; gsub(/[ \t"\047]/, "", d)
        if (d ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) { hasdate[f] = 1; notedate[f] = d }
      }
      if (k == "confidence") confidence[f] = unquote(v)
      if (k == "tags" || k == "source" || k == "code") { if (v == "") cur = k; else additems(f, k, v) }
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
  ismoc[f] = ((f, "moc") in tag)
}
# Longest scanned or privacy-listed project folder that contains path p, or "".
function projectof(p,   k, best) {
  best = ""
  for (k in isproject) if ((p == k || index(p, k "/") == 1) && length(k) > length(best)) best = k
  return best
}
# Does a changed file c (relative to its project) fall under rel (a code path relative to it)?
function under(c, rel) {
  if (rel == "" || rel == c) return 1
  if (rel ~ /\/$/) return index(c, rel) == 1
  return index(c, rel "/") == 1
}
function isref(s) { return s ~ /^[A-Za-z0-9._-]+@[A-Za-z0-9._\/^~-]+$/ && s !~ /^https?:/ }
BEGIN {
  # Config.
  hascfg = 0
  while ((getline line < cfgf) > 0) {
    hascfg = 1
    n = split(line, a, "\t")
    if (n == 2 && a[1] == "privacy") hasprivacy = 1
    if (n == 3 && a[1] == "folders") folder[a[2]] = a[3]
    if (n == 4 && a[1] == "privacy" && a[2] == "projects") { level[a[3]] = a[4]; isproject[a[3]] = 1 }
    if (n == 4 && a[1] == "privacy" && a[2] == "exclude") exclude[++nexclude] = a[4]
    if (n == 4 && a[1] == "lastScan" && a[3] == "commit") { lastscan[a[2]] = a[4]; isproject[a[2]] = 1 }
  }
  close(cfgf)
  split("projects:Projects decisions:Decisions releases:Releases tech:Tech concepts:Concepts proposals:Proposals", defs, " ")
  for (i in defs) { split(defs[i], kv, ":"); if (!(kv[1] in folder)) folder[kv[1]] = kv[2] }
  proposals = folder["proposals"]
  rootdir = ENVIRON["ENGRAM_ROOT"]; tmpdir = ENVIRON["ENGRAM_TMP"]

  while ((getline p < all) > 0) {
    anypath[tolower(p)] = 1; anybase[tolower(base(p))] = 1
    if (p ~ /\.md$/ && top(p) != proposals) {
      k = tolower(p); sub(/\.md$/, "", k); mdpath[k] = p
      s = tolower(stem(p))
      if (s in mdstem) report("DUPLICATE_NAME", p, "same name as " mdstem[s])
      else mdstem[s] = p
    }
  }
  close(all)
  n = 0
  while ((getline p < notes) > 0) {
    if (top(p) == proposals && p ~ /\//) { report("PROPOSAL_PENDING", p, "review, then apply or drop it"); continue }
    note[++n] = p
  }
  close(notes)
  for (i = 1; i <= n; i++) scan(note[i])

  for (i = 1; i <= n; i++) {
    f = note[i]
    if (!hasfm[f]) { report("MISSING_FRONTMATTER", f, ""); continue }
    if (!hasdesc[f]) report("MISSING_DESCRIPTION", f, "")
    if (!hasdate[f]) report("MISSING_DATE", f, datefield)
  }

  # Sources: notes in the role folders scan writes, decisions and notes with code paths need one.
  for (i = 1; i <= n; i++) {
    f = note[i]
    if (!hasfm[f] || ismoc[f] || f == hub || f == logf || ((f, "daily") in tag) || ((f, "status") in tag)) continue
    if (dir(f) == daily || index(f, daily "/") == 1) continue
    t = top(f)
    role = (f ~ /\// && (t == folder["projects"] || t == folder["decisions"] || t == folder["releases"] || \
            t == folder["tech"] || t == folder["concepts"]))
    if ((role || ((f, "decision") in tag) || nitems[f, "code"] > 0) && nitems[f, "source"] == 0) report("MISSING_SOURCE", f, "")
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

  # Decisions inferred only from commits carry confidence: inferred until the user confirms them.
  for (i = 1; i <= n; i++) {
    f = note[i]
    if (!hasfm[f] || ismoc[f]) continue
    if (!(((f, "decision") in tag) || (top(f) == folder["decisions"] && f ~ /\//))) continue
    if (confidence[f] == "inferred") { inferred++; continue }
    if (confidence[f] != "" || nitems[f, "source"] == 0) continue
    allrefs = 1
    for (j = 1; j <= nitems[f, "source"]; j++) if (!isref(items[f, "source", j])) allrefs = 0
    if (allrefs) report("INFERRED_UNMARKED", f, "sources are only commits: add confidence: inferred")
  }

  if (hascfg && rootdir != "") {
    # Code paths must exist under the projects root. One shell loop tests them all.
    codelist = tmpdir "/codepaths"; missingf = tmpdir "/missing"
    printf "" > codelist
    for (i = 1; i <= n; i++) {
      f = note[i]
      for (j = 1; j <= nitems[f, "code"]; j++) {
        p = items[f, "code", j]; sub(/^\.\//, "", p)
        if (p == "" || p ~ /[*?]/ || p ~ /^https?:/) continue
        print p > codelist
      }
    }
    close(codelist)
    system("while IFS= read -r p; do [ -e \"$ENGRAM_ROOT/$p\" ] || printf \"%s\\n\" \"$p\"; done < \"$ENGRAM_TMP/codepaths\" > \"$ENGRAM_TMP/missing\"")
    while ((getline p < missingf) > 0) missing[p] = 1
    close(missingf)
    for (i = 1; i <= n; i++) {
      f = note[i]
      for (j = 1; j <= nitems[f, "code"]; j++) {
        p = items[f, "code", j]; sub(/^\.\//, "", p)
        if (p in missing) report("CODE_PATH_MISSING", f, p)
      }
    }

    # Staleness: files under a note s code paths changed in commits after the projects lastScan
    # commit and after the note was last committed to the vault.
    while ((getline line < changesf) > 0) {
      split(line, a, "\t")
      if (a[2] == "-") { report("STALE", a[1], "lastScan commit " a[3] " not found in the project: re-scan it"); continue }
      nchg[a[1]]++; chgfile[a[1], nchg[a[1]]] = a[3]; chgtime[a[1], nchg[a[1]]] = a[2] + 0
    }
    close(changesf)
    while ((getline line < ntimesf) > 0) { split(line, a, "\t"); ntime[a[1]] = a[2] + 0 }
    close(ntimesf)
    for (i = 1; i <= n; i++) {
      f = note[i]; newest = 0; what = ""
      written = (f in ntime) ? ntime[f] : 0
      for (j = 1; j <= nitems[f, "code"]; j++) {
        p = items[f, "code", j]; sub(/^\.\//, "", p)
        k = projectof(p)
        if (k == "" || !(k in nchg)) continue
        rel = (p == k) ? "" : substr(p, length(k) + 2)
        for (c = 1; c <= nchg[k]; c++)
          if (chgtime[k, c] > written && chgtime[k, c] > newest && under(chgfile[k, c], rel)) {
            newest = chgtime[k, c]; what = k "/" chgfile[k, c]
          }
      }
      if (what != "") report("STALE", f, what " changed after the last scan")
    }

    # Privacy: .engram.json and the read-deny rules must agree; none projects have no notes.
    if (!hasprivacy) report("PRIVACY_UNSET", ".engram.json", "no privacy block: run the privacy step of /engram:setup")
    else {
      settings = ""
      while ((getline line < settingsf) > 0) settings = settings line "\n"
      close(settingsf)
      for (k in level) {
        rule = "\"Read(/" k "/**)\""
        if (level[k] == "none" && !index(settings, rule)) report("PRIVACY_MISMATCH", k, "none in .engram.json but " rule " is missing from .claude/settings.json")
        else if (level[k] != "none" && index(settings, rule)) report("PRIVACY_MISMATCH", k, level[k] " in .engram.json but " rule " is in .claude/settings.json")
        if (level[k] != "full" && level[k] != "structure" && level[k] != "none") report("PRIVACY_MISMATCH", k, "unknown level " level[k])
      }
      for (j = 1; j <= nexclude; j++) {
        rule = "\"Read(./**/" exclude[j] ")\""
        if (!index(settings, rule)) report("PRIVACY_MISMATCH", exclude[j], rule " is missing from .claude/settings.json")
      }
      for (i = 1; i <= n; i++) {
        f = note[i]
        for (key = 1; key <= 2; key++) {
          kk = (key == 1) ? "code" : "source"
          for (j = 1; j <= nitems[f, kk]; j++) {
            p = items[f, kk, j]
            for (k in level) if (level[k] == "none" && (p == k || index(p, k "/") == 1 || index(p, k "@") == 1)) hit[f] = k
          }
        }
        if (f in hit) report("PRIVACY_NONE_NOTES", f, "cites " hit[f] ", which is set to none")
      }
    }
  } else if (hascfg) {
    report("PROJECTS_ROOT_MISSING", ".engram.json", "projectsRoot " ENVIRON["ENGRAM_ROOT_SET"] " is not a folder: code paths, staleness and privacy were not checked")
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
      if (top(f) == proposals && f ~ /\//) continue
      if (!((dailynote, f) in linked)) report("NOT_IN_DAILY", f, dailynote)
    }
  }

  errors = 0
  nerr = split("MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE MISSING_SOURCE BROKEN_LINK ORPHAN NOT_IN_MOC NOT_IN_DAILY CODE_PATH_MISSING PROJECTS_ROOT_MISSING", checks, " ")
  nall = split("MISSING_FRONTMATTER MISSING_DESCRIPTION MISSING_DATE MISSING_SOURCE BROKEN_LINK ORPHAN NOT_IN_MOC NOT_IN_DAILY CODE_PATH_MISSING PROJECTS_ROOT_MISSING NO_MOC DUPLICATE_NAME LIKELY_DUPLICATE STALE INFERRED_UNMARKED PROPOSAL_PENDING PRIVACY_UNSET PRIVACY_MISMATCH PRIVACY_NONE_NOTES DAILY_CHECK_SKIPPED DAILY_CHECK_BY_DATE", checks, " ")
  for (i = 1; i <= nall; i++) {
    printf "SUMMARY\t%s\t%d\n", checks[i], count[checks[i]] + 0
    if (i <= nerr) errors += count[checks[i]]
  }
  printf "SUMMARY\tINFERRED\t%d\n", inferred + 0
  printf "SUMMARY\tNOTES\t%d\n", n
  exit errors > 0 ? 1 : 0
}
' < /dev/null
