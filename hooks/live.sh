#!/bin/sh
# engram live graph: PostToolUse hook for Read, Edit and Write, and Stop hook.
#
# When Claude reads or writes a note inside a vault whose Obsidian runs the engram-live
# plugin, append one JSON line to that vault's .obsidian/plugins/engram-live/live.jsonl:
#   {"v":1,"tool":"Read","path":"Projects/Inkwell/Inkwell.md","session":"<session id>"}
# When Claude finishes a turn, append {"v":1,"event":"stop","session":"<session id>"} so
# the plugin can let the lit notes fade out.
# The plugin creates live.jsonl while it is enabled and removes it when it is disabled, so
# the file is also the switch: without it this script reads its input and exits.
# Vaults are looked for in the project folder, its parent and its grandparent, and one
# level below each. Only the path of the touched file inside the vault and the session id
# are written: no file contents, no paths outside the vault, nothing over the network. Prints nothing and
# always exits 0, so it never shows up in Claude's context.
# POSIX sh and awk; needs Git Bash on Windows.

M=.obsidian/plugins/engram-live/live.jsonl
LIMIT_KB=1024 # stop appending past 1 MB, e.g. when Obsidian quit without unloading the plugin

d=${CLAUDE_PROJECT_DIR:-$PWD}
case $d in *\\*) d=$(printf '%s' "$d" | tr '\\' /) ;; esac

found=
n=0
while [ "$n" -lt 3 ]; do
  for f in "$d/$M" "$d"/*/"$M"; do
    [ -f "$f" ] || continue
    [ -n "$(find "$f" -size +"$LIMIT_KB"k 2>/dev/null)" ] && continue
    found="$found$f
"
  done
  p=${d%/*}
  if [ -z "$p" ] || [ "$p" = "$d" ]; then break; fi
  d=$p
  n=$((n + 1))
done

if [ -z "$found" ]; then
  cat > /dev/null
  exit 0
fi

ENGRAM_LIVE_LOGS=$found ENGRAM_LIVE_SUFFIX=/$M LC_ALL=C awk '
function hexval(h,   i, v, c) {
  v = 0
  for (i = 1; i <= length(h); i++) {
    c = index("0123456789abcdef", tolower(substr(h, i, 1)))
    if (c == 0) return -1
    v = v * 16 + c - 1
  }
  return v
}
function utf8(cp) {
  if (cp < 128) return sprintf("%c", cp)
  if (cp < 2048) return sprintf("%c%c", 192 + int(cp / 64), 128 + cp % 64)
  if (cp < 65536) return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + int(cp / 64) % 64, 128 + cp % 64)
  return sprintf("%c%c%c%c", 240 + int(cp / 262144), 128 + int(cp / 4096) % 64, 128 + int(cp / 64) % 64, 128 + cp % 64)
}
# The string value of the first "key":"..." in the input. Inside JSON strings every quote is
# escaped, so an unescaped "key": can only be a real key.
function jstr(key,   rest, i, n, c, e, out, cp, lo) {
  if (!match(s, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"")) return ""
  rest = substr(s, RSTART + RLENGTH, 8192)
  n = length(rest)
  out = ""
  for (i = 1; i <= n; i++) {
    c = substr(rest, i, 1)
    if (c == "\"") return out
    if (c != "\\") { out = out c; continue }
    e = substr(rest, ++i, 1)
    if (e == "u") {
      cp = hexval(substr(rest, i + 1, 4)); i += 4
      if (cp >= 55296 && cp < 56320 && substr(rest, i + 1, 2) == "\\u") {
        lo = hexval(substr(rest, i + 3, 4))
        if (lo >= 56320 && lo < 57344) { cp = 65536 + (cp - 55296) * 1024 + (lo - 56320); i += 6 }
      }
      if (cp < 0) return ""
      out = out utf8(cp)
    }
    else if (e == "n") out = out "\n"
    else if (e == "t") out = out "\t"
    else if (e == "r") out = out "\r"
    else if (e == "b" || e == "f") out = out " "
    else out = out e
  }
  return ""
}
# Forward slashes, Git Bash drive form (/c/x) as c:/x, no empty, "." or ".." segments.
function norm(p,   n, a, i, k, st, out) {
  if (p ~ /^[A-Za-z]:\\/ || p ~ /^\\\\/) gsub(/\\/, "/", p)
  if (p ~ /^\/[A-Za-z]\//) p = substr(p, 2, 1) ":" substr(p, 3)
  n = split(p, a, "/")
  k = 0
  for (i = 1; i <= n; i++) {
    if (a[i] == "" && i > 1) continue
    if (a[i] == ".") continue
    if (a[i] == ".." && k > 1) { k--; continue }
    st[++k] = a[i]
  }
  out = st[1]
  for (i = 2; i <= k; i++) out = out "/" st[i]
  return out
}
function jesc(v) {
  gsub(/\\/, "\\\\", v)
  gsub(/"/, "\\\"", v)
  gsub(/[\001-\037]/, "", v)
  return v
}
{ s = s $0 "\n" }
END {
  session = jesc(jstr("session_id"))
  suffix = ENVIRON["ENGRAM_LIVE_SUFFIX"]
  nlogs = split(ENVIRON["ENGRAM_LIVE_LOGS"], logs, "\n")
  if (jstr("hook_event_name") == "Stop") {
    for (j = 1; j <= nlogs; j++) {
      if (logs[j] == "") continue
      printf "{\"v\":1,\"event\":\"stop\",\"session\":\"%s\"}\n", session >> logs[j]
      close(logs[j])
    }
    exit 0
  }
  tool = jstr("tool_name")
  if (tool !~ /^(Read|Edit|Write|MultiEdit)$/) exit 0
  path = jstr("file_path")
  if (path == "") exit 0
  if (path !~ /^\// && path !~ /^[A-Za-z]:[\\\/]/ && path !~ /^\\\\/) {
    cwd = jstr("cwd")
    if (cwd == "") exit 0
    path = cwd "/" path
  }
  path = norm(path)
  lpath = tolower(path)
  for (j = 1; j <= nlogs; j++) {
    lf = logs[j]
    if (lf == "") continue
    vault = norm(substr(lf, 1, length(lf) - length(suffix)))
    if (index(lpath, tolower(vault) "/") != 1) continue
    rel = substr(path, length(vault) + 2)
    if (rel == "" || rel ~ /^\./ || rel ~ /\/\./) continue
    printf "{\"v\":1,\"tool\":\"%s\",\"path\":\"%s\",\"session\":\"%s\"}\n", jesc(tool), jesc(rel), session >> lf
    close(lf)
  }
}' 2>/dev/null

exit 0
