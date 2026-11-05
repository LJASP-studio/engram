#!/bin/sh
# edited.sh: which notes hold your own edits, so engram never overwrites them. POSIX sh + awk + git.
#
# Usage: edited.sh VAULT [NOTE ...]
#   NOTE  path of a note: relative to the vault, or absolute inside it (default: every note)
#
# Prints, relative to the vault, each given note that has uncommitted changes, or whose history
# (renames followed) has a commit engram did not make. engram's own commits start with "docs: "
# or "chore: ". "chore: snapshot manual edits" stores your edits and "docs: merge " carries
# them into another note, so both count as yours. In a vault with no commits yet, or one that
# is not a git repository, every note is printed.
# Exit status: 0, or 2 on bad usage or when a NOTE is neither on disk nor in git (fix the path).

set -eu

if [ $# -lt 1 ] || [ ! -d "$1" ]; then
  echo "usage: edited.sh VAULT [NOTE ...]" >&2
  exit 2
fi
cd "$1"; shift
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t engram)
trap 'rm -rf "$TMP"' EXIT INT TERM

ISREPO=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
   [ -z "$(git rev-parse --show-prefix 2>/dev/null)" ]; then
  ISREPO=1
fi

# Turn each argument into a vault-relative path with forward slashes.
VP=$(pwd -P); VL=$(pwd); VG=""
[ "$ISREPO" = 1 ] && VG=$(git rev-parse --show-toplevel 2>/dev/null || :)
STATUS=0
: > "$TMP/want"
if [ $# -gt 0 ]; then
  for a in "$@"; do
    p=$(printf '%s' "$a" | tr '\\' '/')
    case $p in "$VP"/*) p=${p#"$VP"/} ;; "$VL"/*) p=${p#"$VL"/} ;; esac
    if [ -n "$VG" ]; then case $p in "$VG"/*) p=${p#"$VG"/} ;; esac; fi
    while :; do case $p in ./*) p=${p#./} ;; *) break ;; esac; done
    if [ ! -e "$p" ] && ! { [ "$ISREPO" = 1 ] && git cat-file -e "HEAD:$p" 2>/dev/null; }; then
      echo "edited.sh: not a note in this vault: $a" >&2
      STATUS=2
      continue
    fi
    printf '%s\n' "$p" >> "$TMP/want"
  done
else
  find . \( -name .git -o -name .obsidian -o -name .trash \) -prune -o -type f -name '*.md' -print |
    sed 's|^\./||' > "$TMP/want"
fi

if [ "$ISREPO" = 0 ] || ! git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  echo "edited.sh: the vault has no git history yet; treating every note as yours" >&2
  LC_ALL=C sort -u "$TMP/want"
  exit "$STATUS"
fi

{
  # Uncommitted: changed since the last commit, or never committed.
  git -c core.quotePath=false diff --name-only HEAD --
  git -c core.quotePath=false ls-files --others --exclude-standard
  # Committed by someone other than engram. History runs newest first, so a rename maps the
  # older name to the file's current name.
  git -c core.quotePath=false log -M --name-status --format='@%s' |
    awk -F '\t' '
      function now(p) { while (p in renamed) p = renamed[p]; return p }
      /^@/ {
        s = substr($0, 2)
        human = (s !~ /^(docs|chore): / || s == "chore: snapshot manual edits" || s ~ /^docs: merge /)
        next
      }
      NF >= 2 {
        if ($1 ~ /^R/) { t = now($3); if (t != $2) renamed[$2] = t; if (human) print t; next }
        if (human) print now($2)
      }'
} | LC_ALL=C sort -u > "$TMP/yours"

LC_ALL=C sort -u "$TMP/want" | LC_ALL=C comm -12 - "$TMP/yours"
exit "$STATUS"
