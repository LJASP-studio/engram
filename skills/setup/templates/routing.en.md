<!-- engram:start -->
## Brain vault
Project knowledge lives in the `{{vault}}/` vault (Obsidian). Every note has a one-line `description:` and a `code:` field with the paths it describes. Before searching code:
1. Grep the `^description:` lines in `{{vault}}/` for the question's key words (with `-A 4`, so the `source:` and `code:` lines come too). Most questions end here: go to the `code:` paths.
2. If nothing matches or the question is broad, read `{{vault}}/{{hub}}.md`, then the index of the folder that fits (`{{vault}}/<Folder>/<Folder>.md`); for questions across projects, `{{vault}}/{{concepts}}/{{concepts}}.md`.
3. Open at most 3 notes. Search the code only if the notes do not answer.
When a task is done, write it down with `/engram:note`. The vault stays on this machine in local git; never add a remote.
<!-- engram:end -->
