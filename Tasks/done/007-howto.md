# Howto

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Write `scripts/howto.md` — end-user instructions. Adapt the reference's `howto.md` to this project's differences.

Cover:
- What the project does (3MF contact sheet spanning multiple folders on disk).
- Configuring `3mffolders.md`: one folder per line, trailing ` *` = recurse, `#` = comment. Give two or three example lines.
- Running the refresh — both Options: double-click `scripts/refresh.cmd`, or `bash scripts/refresh.sh` from Git Bash.
- Opening `_index.html` — double-click in Explorer; clicking a card opens the `.3mf` in the default app (slicer).
- Folder layout of generated artifacts (`_index.html`, `thumbnails/<slug>/…`).
- Script-by-script table (same shape as the reference).
- Dependencies: bash + unzip, both from Git for Windows.
- Troubleshooting: `unzip: command not found`, files with no extractable thumbnail, count-guard abort, empty-3mffolders abort.

Done when: a reader who has never touched this project can configure `3mffolders.md`, run the refresh, open the index, and diagnose the common error paths using only this document.

## Notes
- Read all four scripts (`parse_folders.sh`, `extract_thumbnails.sh`, `generate_index.sh`, `refresh.sh`) plus `refresh.cmd` and documented actual behavior, not the task specs.
- Structure and tone borrowed from the reference `D:\3D\Space Monkey 3D Designs\scripts\howto.md`: folder-layout diagram, two-option refresh, script table, dependencies, troubleshooting.
- Adapted to this project's differences: multi-root scanning driven by `3mffolders.md`, slug scheme for thumbnails/, generated artifacts at repo root, `file:///` card links, relaxed trailing-`*` parser, `#`/blank-line skipping, count-guard abort message, empty/missing `3mffolders.md` abort, "path does not exist" warnings.
- Included an explicit slug example (`D:\3D\Space Monkey 3D Designs` → `D__3D_Space_Monkey_3D_Designs`) and the preview-path fallback chain.
- No discrepancies found between the scripts and the task-file behavior description — the scripts implement the relaxed `*` parser, `#`/blank-line skipping, warning (not abort) on missing paths, abort on empty/missing folders file, and the pre-generate count-guard as described.

## Questions
