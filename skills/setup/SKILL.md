---
name: setup
description: Set up an engram vault in the current projects folder (layout, hub, MOCs, privacy per project, routing block, read-deny rules, Obsidian presets, local git). `privacy` re-runs only the privacy step; `live` adds the live graph plugin.
argument-hint: "[tr|en] [vault-folder] | privacy | live"
disable-model-invocation: true
---

# Set up a vault

Run from the folder that holds the projects (for example `~/code` or `D:/code`). The vault becomes a subfolder of it. Read `${CLAUDE_SKILL_DIR}/../../reference/conventions.md` first. Templates are in `${CLAUDE_SKILL_DIR}/templates/`. Use Claude's own tools (Read, Write, Edit, Glob, Grep) for files and JSON; use the shell only for `git`. Never add a git remote and never push.

Arguments: `$ARGUMENTS` (optional language `tr` or `en`, optional vault folder name). If the arguments are `privacy`, find the vault (conventions), ask only items 4 and 5 of step 2, run steps 6 and 7, commit `.engram.json` (`chore: update privacy`) and report. If they are `live`, find the vault and run step 9 only.

## 1. Check the place
- The projects root is the current working directory. Run `git rev-parse --show-toplevel` there. If it is inside a git repository, the vault would be committed into that repository: stop and ask whether to use the parent folder instead.
- Look for an existing vault: `.engram.json` or `.obsidian/` one level down. If one exists, adopt it (step 3b) instead of creating a new one. If the projects root itself holds `.obsidian/`, stop: the vault must be a subfolder, or its git repository would take in every project.

## 2. Ask once
Look around first, then put every question in one message with a suggested answer on each line, so the user can reply `ok` or change only the lines they want. Leave out what the arguments already answer. Ask again only about an answer that is unclear; take the rest as given.
1. Note language: English (`en`) or Turkish (`tr`); suggest the language the user writes in. It sets the text of the hub, the log, the indexes and the routing block, and the language later notes are written in. The structure stays English either way (conventions).
2. Vault folder name: suggest `brain`, or the existing vault's name.
3. Existing vault only (step 3b): which of its folders play the roles in `folders` (projects, decisions, releases, tech, concepts, daily) and which note is the hub; suggest the closest names, and "new" where nothing fits.
4. What Claude may read in each top-level folder of the projects root (by name only; not the vault, not hidden folders): `full` (docs, code and git history), `structure` (file names only) or `none` (skipped). Suggest the current level from `privacy.projects`, else `full`. Add one line: on a work computer, check the employer's policy on sending company code to an LLM service before choosing `full`.
5. Files never read: the `privacy.exclude` patterns (default list in `layout.json`) and the read-deny rules of step 7, summed up in a line or two (for example "`.env` files, keys, certificates and credentials (25 patterns), plus build output and lock files"); the user can add or remove any.

Example for a new vault:
```
Ready to set up engram here. Reply "ok", or change any line:
1. Note language: en
2. Vault folder: brain
3. What Claude may read: api full · web full · old-site full   (full = docs, code, history · structure = file names only · none = skip)
4. Never read: .env files, keys, certificates and credentials (25 patterns), plus build output and lock files
On a work computer, check your employer's policy before choosing full.
```

## 3a. New vault
Replace `{{today}}` with today's date and the other `{{…}}` placeholders with the names in `layout.json`.
1. `<vault>/.engram.json` from `layout.json`, with `language` set to the chosen language.
2. Folders from `folders` except `proposals` (created when the first proposal is written), plus the `views` folder.
3. Hub `<vault>/<hub>.md` from `hub.<language>.md`; log `<vault>/<log>.md` from `log.<language>.md`.
4. One MOC per role folder from `moc.md`, named after the folder, inside it (the views and proposals folders get none). `mocDescription`: one sentence on what the folder holds. `intro`: one line. `lines`: empty for now. `up`: `Up: [[<hub>]]` (in Turkish text `Üst: [[<hub>]]`). Write `mocDescription` and `intro` in the note language.
5. Today's daily note `<daily>/<today>.md`: frontmatter (description, date, tag `daily`), heading `# <today>`, one summary line ("Vault set up" or "Kasa kuruldu") and `Related: [[<hub>]]` (in Turkish text `İlgili:`). Add `- [[<today>]]: <description>` to the daily MOC.
6. Bases into the views folder: `bases/decisions.base` as `Decision table.base`, `releases.base` as `Release table.base`, `orphans.base` as `Orphans.base`. Fill `{{decisions}}`, `{{releases}}` and `{{proposals}}` with the folder names.
7. `<vault>/.obsidian/`: write each of these files only if that file does not exist yet: `app.json` (`{"useMarkdownLinks": false, "alwaysUpdateLinks": true}`), `daily-notes.json` (`{"folder": "<daily>", "format": "YYYY-MM-DD"}`) and `graph.json` from the template with the folder names filled in. If `graph.json` already exists, leave it and tell the user the preset is at `${CLAUDE_SKILL_DIR}/templates/graph.json`; Obsidian overwrites graph.json on exit, so it must be edited with Obsidian closed.
8. `<vault>/.gitignore` from `templates/gitignore`.

## 3b. Existing vault
Do not move or rename anything. Its notes are the user's, so mark them before adding anything: if the vault is not a git repository yet, run `git -C <vault> init -b main`; then, if `git -C <vault> status --porcelain` is not empty, `git -C <vault> add -A` and `git -C <vault> commit -m "chore: snapshot manual edits"` (conventions, Your edits). Then write `.engram.json` with the role folders and hub from step 2 and the `privacy` block from `layout.json`. Create only what is missing: role folders, MOCs, log, views, `.gitignore`. Keep `.obsidian/` as it is. Notes without `description` or a date are fixed later with `/engram:check`.

## 4. Local git
In the vault: if `git -C <vault> rev-parse --show-toplevel` is not the vault itself, run `git -C <vault> init -b main`. Check `git -C <vault> remote` is empty; if a remote exists, tell the user and do not touch it. Commit what setup created: `git -C <vault> add -A` and `git -C <vault> commit -m "chore: set up the vault"`.

## 5. Routing block
Fill `routing.<language>.md` (`{{vault}}`, `{{hub}}`, `{{concepts}}`). In `<projects root>/CLAUDE.md`, replace the text between `<!-- engram:start -->` and `<!-- engram:end -->` if it is there, else append the block at the end. Create the file if it does not exist. Keep everything else in the file.

## 6. Privacy
What an LLM may read is decided per machine (conventions, Privacy). Use the answers to items 4 and 5 of step 2.
1. Write the level of each folder and the exclude patterns into `.engram.json`. For a folder now set to `none`, remove its `lastScan` entry.
2. Sync the read-deny rules in `permissions.deny` of `<projects root>/.claude/settings.json`: add `Read(/<folder>/**)` for every `none` folder and `Read(./**/<pattern>)` for every exclude pattern; remove a `Read(/<folder>/**)` whose folder is no longer `none` and a `Read(./**/<pattern>)` whose pattern was removed. Touch no other rule or key. Mention that a `Read` deny rule also stops Claude from editing files in that folder from this projects root, and that `/engram:setup privacy` opens a folder again whenever the user wants.
3. If notes cite a folder that is now `none` (Grep its name followed by `/` or `@` in `source:` and `code:` lines), list them and ask whether to delete them; deleting needs a yes.

## 7. Read-deny rules
Build the list from `templates/deny.json`: everything in `always`, plus each `ifFound` group whose file patterns Glob finds at `<pattern>`, `*/<pattern>` or `*/*/<pattern>` under the root (skip `none` folders); build it before step 2, since item 5 shows it. Apply the user's changes from step 2 and merge it into `permissions.deny` of `<projects root>/.claude/settings.json`: create the file if missing, keep every other key, add no duplicates.

## 8. Report
Keep it short: the vault's path, the level of each folder, and the files changed outside the vault (`CLAUDE.md`, `.claude/settings.json`). Commit `.engram.json` if it changed after step 4. Then the next step on its own line: run `/engram:scan`, which reads the projects, shows a plan and writes nothing before the user's OK. Mention that nothing here is pushed anywhere, that `/engram:setup privacy` changes the levels later, and that `/engram:setup live` adds a live graph to Obsidian.

## 9. Live graph (`live` only)
An Obsidian plugin that lights up a note in the graph view while Claude reads or writes it; the engram plugin's hook (`hooks/live.sh`) feeds it and does nothing until the plugin is enabled. Never run this step unasked.
1. Copy `main.js`, `manifest.json` and `styles.css` from `${CLAUDE_SKILL_DIR}/../../obsidian/engram-live/` into `<vault>/.obsidian/plugins/engram-live/` with `cp` (Read and Write if there is no shell). Replace only these three files; keep `data.json`, the user's settings. The folder name must stay `engram-live`, or the hook cannot find it.
2. Commit them in the vault: `git -C <vault> add .obsidian/plugins/engram-live` and `git -C <vault> commit -m "chore: add the live graph plugin"`.
3. Tell the user, in the note language: in Obsidian, Settings → Community plugins → turn off Restricted mode and enable "engram live graph", then open the graph view. A note a search returned glows faintly, a note Claude reads lights up bright, an edited or new note in a third color; lit notes glow while Claude works, sparks run along the links of opened notes, the rest dim and a counter shows notes read out of all notes, plus the search matches. When Claude finishes its turn, everything fades out slowly. The plugin's settings hold the colors and timings; the command "Reset the live graph" fades it out at once. Obsidian pauses animations while its window is hidden. Turning the plugin off stops the hook too. Running this step again updates the plugin after an engram update.
