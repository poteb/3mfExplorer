# Create Scaffold

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Lay down the file/folder skeleton so subsequent tasks have concrete files to edit. No logic yet.

- Create `scripts/` with these files, each containing only a `#!/usr/bin/env bash` shebang and a one-line header comment naming the script:
  - `scripts/refresh.sh`
  - `scripts/parse_folders.sh`
  - `scripts/extract_thumbnails.sh`
  - `scripts/generate_index.sh`
- Create `scripts/refresh.cmd` as the Windows double-click wrapper (same 4-line pattern as the reference: `@echo off` / `cd /d "%~dp0"` / `bash refresh.sh` / `pause`).
- Create `scripts/howto.md` as an empty file (content lands in task 007).
- Create `.gitignore` at repo root containing:
  - `/_index.html`
  - `/thumbnails/*`
  - `!/thumbnails/.gitkeep`
- Create `thumbnails/.gitkeep` so the empty folder is tracked.

Leave `3mffolders.md` as-is (the user owns its content).

Done when: the tree matches the "Proposed repo layout after scaffold" section in `Tasks/done/001-plan-scaffold.md`, and `git status` shows all the new files untracked.

## Notes

- Created the four `.sh` stubs under `scripts/` (`refresh.sh`, `parse_folders.sh`, `extract_thumbnails.sh`, `generate_index.sh`), each just a `#!/usr/bin/env bash` shebang plus a one-line header comment naming the script.
- Created `scripts/refresh.cmd` using the exact 4-line pattern from `D:\3D\Space Monkey 3D Designs\scripts\refresh.cmd`: `@echo off` / `cd /d "%~dp0"` / `bash refresh.sh` / `pause`.
- Created empty `scripts/howto.md` (content deferred to task 007).
- Wrote `.gitignore` at repo root with `/_index.html`, `/thumbnails/*`, `!/thumbnails/.gitkeep` (exact lines from the task spec).
- Created `thumbnails/.gitkeep` so the otherwise-ignored folder is tracked.
- Left `3mffolders.md`, `Project.md`, and `CLAUDE.md` untouched.
- Verified with `git ls-files --others --exclude-standard` — all eight new scaffold files (`.gitignore`, `scripts/*.sh` x4, `scripts/refresh.cmd`, `scripts/howto.md`, `thumbnails/.gitkeep`) show up as untracked. No accidental writes under `_index.html` or generated paths; gitignore rules will take effect once those are generated in later tasks.
- Tree now matches the "Proposed repo layout after scaffold" section in `Tasks/done/001-plan-scaffold.md`.

## Questions
