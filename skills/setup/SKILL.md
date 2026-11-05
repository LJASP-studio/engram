---
name: setup
description: Set up an engram vault in the current projects folder (layout, hub, MOCs, routing block, read-deny rules, Obsidian presets, local git).
argument-hint: "[tr|en] [vault-folder]"
disable-model-invocation: true
---

# Set up a vault

Run from the folder that holds the projects (for example `~/code` or `D:/code`). The vault becomes a subfolder of it. Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` first. Templates are in `${CLAUDE_SKILL_DIR}/templates/`. Use Claude's own tools (Read, Write, Edit, Glob, Grep) for files and JSON; use the shell only for `git`. Never add a git remote and never push.

Arguments: `$ARGUMENTS` (optional language `tr` or `en`, optional vault folder name).

## 1. Check the place
- The projects root is the current working directory. Run `git rev-parse --show-toplevel` there. If it is inside a git repository, the vault would be committed into that repository: stop and ask whether to use the parent folder instead.
- Look for an existing vault: `.engram.json` or `.obsidian/` in the root or one level down. If one exists, adopt it (step 3b) instead of creating a new one.

## 2. Ask
- Note language, unless given in the arguments: English (`en`) or Turkish (`tr`). It sets the text of the hub, the log, the indexes and the routing block, and the language later notes are written in. The structure stays English either way (conventions).
- Vault folder name, unless given: default `brain`.

## 3a. New vault
Replace `{{today}}` with today's date and the other `{{…}}` placeholders with the names in `layout.json`.
1. `<vault>/.engram.json` from `layout.json`, with `language` set to the chosen language.
2. Folders from `folders`, plus the `views` folder.
3. Hub `<vault>/<hub>.md` from `hub.<language>.md`; log `<vault>/<log>.md` from `log.<language>.md`.
4. One MOC per role folder from `moc.md`, named after the folder, inside it (the views folder holds only `.base` files and gets none). `mocDescription`: one sentence on what the folder holds. `intro`: one line. `lines`: empty for now. `up`: `Up: [[<hub>]]` (in Turkish text `Üst: [[<hub>]]`). Write `mocDescription` and `intro` in the note language.
5. Today's daily note `<daily>/<today>.md`: frontmatter (description, date, tag `daily`), heading `# <today>`, one summary line ("Vault set up" or "Kasa kuruldu") and `Related: [[<hub>]]` (in Turkish text `İlgili:`). Add `- [[<today>]]: <description>` to the daily MOC.
6. Bases into the views folder: `bases/decisions.base` as `Decision table.base`, `releases.base` as `Release table.base`, `orphans.base` as `Orphans.base`. Fill `{{decisions}}` and `{{releases}}` with the folder names.
7. `<vault>/.obsidian/`: write each of these files only if that file does not exist yet: `app.json` (`{"useMarkdownLinks": false, "alwaysUpdateLinks": true}`), `daily-notes.json` (`{"folder": "<daily>", "format": "YYYY-MM-DD"}`) and `graph.json` from the template with the folder names filled in. If `graph.json` already exists, leave it and tell the user the preset is at `${CLAUDE_SKILL_DIR}/templates/graph.json`; Obsidian overwrites graph.json on exit, so it must be edited with Obsidian closed.
8. `<vault>/.gitignore` from `templates/gitignore`.

## 3b. Existing vault
Do not move or rename anything. Ask which existing folders play the roles in `folders` (projects, decisions, releases, tech, concepts, daily) and which note is the hub; write `.engram.json` with those names. Create only what is missing: role folders, MOCs, log, views, `.gitignore`. Keep `.obsidian/` as it is. Notes without `description` or a date are fixed later with `/engram:check`.

## 4. Local git
In the vault: if `git -C <vault> rev-parse --show-toplevel` is not the vault itself, run `git -C <vault> init -b main`. Check `git -C <vault> remote` is empty; if a remote exists, tell the user and do not touch it. Commit: `git -C <vault> add -A` then `git -C <vault> commit -m "chore: set up the vault"`.

## 5. Routing block
Fill `routing.<language>.md` (`{{vault}}`, `{{hub}}`). In `<projects root>/CLAUDE.md`, replace the text between `<!-- engram:start -->` and `<!-- engram:end -->` if it is there, else append the block at the end. Create the file if it does not exist. Keep everything else in the file.

## 6. Read-deny rules
Build the list from `templates/deny.json`: everything in `always`, plus each `ifFound` group whose file patterns Glob finds at `<pattern>`, `*/<pattern>` or `*/*/<pattern>` under the root. Show the list and ask once before writing. Merge it into `permissions.deny` of `<projects root>/.claude/settings.json`: create the file if missing, keep every other key, add no duplicates.

## 7. Attribution
Ask whether commits and PRs made from this folder should carry no Claude attribution. On yes, set `"attribution": {"commit": "", "pr": "", "sessionUrl": false}` in the same settings file.

## 8. Report
List what was created or changed, with paths. Next step: `/engram:scan` to scan the projects. Mention that nothing here is pushed anywhere.
