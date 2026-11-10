# Install, update, remove

## Before you start

- Claude Code and git.
- Obsidian, if you want to browse the vault and watch the graph. engram works without it.
- On Windows, Git for Windows. engram's helper scripts and the live graph hook run in its Git Bash; without it Claude Code falls back to PowerShell and they do not run.

## Install

From a terminal:

```sh
claude plugin marketplace add LJASP-studio/engram
claude plugin install engram@engram
```

Or inside Claude Code:

```
/plugin marketplace add LJASP-studio/engram
/plugin install engram@engram
```

Inside Claude Code, `/plugin install` opens a panel where you pick the scope; "user" makes engram available in every folder. If you installed from a terminal while Claude Code was open, run `/reload-plugins` there or restart it.

engram adds about 300 tokens to each session: the names and one-line descriptions of its four skills. A skill's full text loads only when it runs.

## Set up

1. Open Claude Code in the folder that holds your projects, for example `~/code`, not inside one of them. The vault becomes a subfolder there. If your projects live in different places, use the folder they share, or move them under one.
2. Run `/engram:setup`. It asks everything in one message: note language, vault folder name, what Claude may read in each project and which files it never reads. Reply `ok` to take its suggestions.
3. Run `/engram:scan`. It reads each project with a read-only helper, shows you a plan and writes nothing until you say OK. A large workspace takes a while the first time; later scans read only what changed.

Setup changes three things on your machine:

- `brain/`: the vault, a local git repository with no remote.
- `CLAUDE.md` in the projects folder: a short block between `<!-- engram:start -->` and `<!-- engram:end -->` that tells Claude to look in the vault before the code.
- `.claude/settings.json` in the projects folder: read-deny rules for secrets, build output and any project you set to `none`.

## Obsidian

Open the vault with "Open folder as vault". For the live graph, run `/engram:setup live`, then in Obsidian go to Settings → Community plugins, turn off Restricted mode and enable "engram live graph".

## Update

```sh
claude plugin marketplace update engram
claude plugin update engram@engram
```

Then run `/reload-plugins` or restart Claude Code. If you use the live graph, run `/engram:setup live` again to update the Obsidian plugin.

To get updates without these commands, open `/plugin`, go to Marketplaces, choose engram and turn on auto-update. It is off by default for plugins outside Anthropic's own marketplace.

## Remove

```sh
claude plugin uninstall engram@engram
claude plugin marketplace remove engram
```

The vault stays where it is: plain Markdown you can keep, open in Obsidian or delete. To undo the rest, remove the engram block from `CLAUDE.md` and any read-deny rules you no longer want from `.claude/settings.json`.

## If something goes wrong

- `/engram:setup` is not in the list: run `/reload-plugins`, or restart Claude Code.
- Setup stops because the folder is inside a git repository: the vault would end up in that repository's history. Open Claude Code one folder up.
- Scan asks about a folder: the folder is new since setup. Choose `full`, `structure` or `none`; the answer is kept.
- On Windows, `sh` is not found: install Git for Windows and restart Claude Code.
- Anything else: open an issue with what you ran and what you saw.
