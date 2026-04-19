# 3mfExplorer — working agreement

## Project
`Project.md` is the project description — the vision and context. Read it first. Never edit it unless I explicitly say so.

`3mffolders.md` lists folders to scan. A trailing `*` means "recurse into subfolders"; no `*` means "root only". May be empty during early development — tolerate that.

Reference implementation: `D:\3D\Space Monkey 3D Designs` (and its `CLAUDE.md`). Same idea — extract embedded `.3mf` previews, generate a static HTML index. Match its tech choices (bash + unzip, no JS deps) unless I say otherwise.

## Task workflow

Tasks live as one file per task under `Tasks/`, named `YYYYMMDD-HHMMSS-short-slug.md` (UTC timestamp + kebab-case slug, e.g. `20260419-145321-scaffold.md`). Timestamps make filenames unique across contributors without coordination. `Tasks/done/` (the archive) IS the log — listed chronologically by filename.

> **Legacy note**: historical tasks in `Tasks/done/` use the older `NNN-slug.md` format and `Done.md` was a flat log. They're kept as archive — don't retroactively rename. New tasks use the timestamp format above; don't append to `Done.md` anymore.

- **You create** task files in the main conversation. Set initial Status to `todo` and write what needs to be done.
- **Execution is always delegated to a sub-agent** (via the `Agent` tool), so the main conversation stays free for me. When I say "Proceed", dispatch an agent to take the **earliest** `todo` task (smallest filename = oldest-created). "Proceed with `<slug>`" dispatches an agent for the task whose slug matches. Default subagent type: `general-purpose`. Prefer `run_in_background: true` so I can keep typing while it works.
- **The agent does the bookkeeping**: Status → `in progress`, append progress/decisions/findings to `## Notes` as it works, Status → `done` when finished, and move the file from `Tasks/` to `Tasks/done/`.
- **If the agent needs input**, it sets Status to `blocked`, writes the question in `## Questions`, and returns — you then flag it in chat so I can answer. Auto-proceed pauses until I respond.
- **Auto-proceed**: when an agent finishes a task cleanly (status `done`), immediately dispatch the next-earliest `todo` task in a fresh agent, with no prompt from me. Surface a one-line "`<slug>` done; starting `<next-slug>`" update in chat. Stop auto-proceeding when: (a) no `todo` tasks remain, (b) a task ends `blocked`, (c) the agent errors or fails verification, or (d) I say "stop" / "pause".
- **Brief the agent well**: the agent starts with no conversation context, so the dispatch prompt must tell it to read its task file by path (the file in `Tasks/` whose filename contains its slug), follow this CLAUDE.md's workflow rules, and include any decisions from prior tasks it needs. Point it at relevant files by path.

### Task file template

````markdown
# <title>

## Status
todo  <!-- todo | in progress | blocked | done -->

## Task
<what needs to be done>

## Notes
<I append progress, decisions, findings as I work>

## Questions
<optional; only when blocked>
````

## Parallelism
Dispatch parallel agents (or worktrees) only when tasks are genuinely independent — no shared files, no sequential dependency, and the work is big enough that serial execution would be slow. A single edit or a quick read doesn't qualify. Default to serial.

## Branches, worktrees, commits, PRs
Handle branching yourself when it helps — e.g. use a git worktree for an isolated feature, or a topic branch for anything larger than a small fix. Direct commits to `main` are fine for small, obviously-correct changes (typos, doc tweaks, single-file fixes).

Commit messages: short imperative subject, body only if the "why" isn't obvious from the diff. One logical change per commit.

Open a PR when the change is large, risky, or you want review before merge. Otherwise just commit. Don't push or force-push without asking.
