# Plan Scaffold

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Read Project.md and make a plan to make a scaffold for this. Look in "D:\3D\Space Monkey 3D Designs" for how I've made something similar with. "D:\3D\Space Monkey 3D Designs\scripts" has the bash (.sh) files and some use guidance.

## Notes

### Source of truth

- `Project.md` — bash scripts generate static HTML; scan folders listed in `3mffolders.md`; trailing `*` recurses, no `*` = root only; each listed folder is its own top-level section, recursed subdirs are subsections.
- Reference: `D:\3D\Space Monkey 3D Designs\scripts\` — bash + unzip only, no JS/node/python deps. Three scripts chained via a refresh wrapper, plus a `.cmd` for Explorer double-click.

### Tech choices (locked)

- Bash + `unzip`, both from Git for Windows.
- No build step, no package manager, no JS framework.
- Single static `_index.html`, dark theme, small inline JS only for localStorage-remembering expand/collapse state (copy from reference).
- `.3mf` previews pulled from `Metadata/plate_1.png` → `top_1.png` → `plate_1_small.png` fallbacks (copy from reference).
- Count-guard before rewriting `_index.html` (copy from reference).

### Key differences from the reference

1. **Content is scattered.** Reference scans its own subfolders as categories. Ours reads arbitrary absolute paths from `3mffolders.md`. Need a small parser for that file.
2. **Optional recursion.** Reference is one level deep. Ours has a per-line `*` flag — recurse or not. Each recursed subdir becomes a nested `<details>` subsection.
3. **Output location.** Reference puts `_index.html` and `thumbnails/` next to the content. Our content is on many paths, so generated artifacts live inside this repo (`D:\git\3mfExplorer\`).
4. **Link scheme.** Reference links are repo-relative. Ours point to absolute paths on disk → need `file:///D:/...` URIs. Double-clicking the index in Explorer opens `file:///` hrefs fine in Chrome/Edge/Firefox; no flags needed.
5. **Thumbnail storage.** Source paths can collide across listed folders (two different trees can both contain `Animals/dragon.3mf`). Need a collision-safe scheme — mirror each listed folder under `thumbnails/<slug-of-listed-folder>/<relative-subpath>/<file>.png`, where the slug is a sanitized version of the listed folder's absolute path.

### Decisions (resolved)

1. **Generated-artifact location** → repo root: `D:\git\3mfExplorer\_index.html` and `D:\git\3mfExplorer\thumbnails\`.
2. **Thumbnail collision scheme** → `thumbnails/<slug-of-listed-folder>/<relative-subpath>/<file>.png`, slug = sanitized absolute path (e.g. `D:\3D\Space Monkey 3D Designs` → `D__3D_Space-Monkey-3D-Designs` or similar).
3. **Link scheme** → `file:///D:/path/to/file.3mf` hrefs, opened by double-clicking `_index.html` in the browser.
4. **`*` recursion depth** → unlimited; every subdir at any depth becomes a nested `<details>` subsection.
5. **Empty `3mffolders.md`** → abort the refresh with a clear error (no friendly empty page).

### Proposed repo layout after scaffold

```
D:\git\3mfExplorer\
├── 3mffolders.md            ← user-edited, list of folders
├── Project.md               ← unchanged
├── CLAUDE.md                ← unchanged
├── Done.md                  ← task log
├── .gitignore               ← generated artifacts ignored
├── Tasks/                   ← task files
├── scripts/
│   ├── refresh.cmd          ← Explorer double-click wrapper
│   ├── refresh.sh           ← orchestrator + count-guard
│   ├── parse_folders.sh     ← emits "<abs-path>\t<recurse-flag>" lines from 3mffolders.md
│   ├── extract_thumbnails.sh
│   ├── generate_index.sh
│   └── howto.md             ← end-user instructions
├── thumbnails/              ← generated; .gitignored except .gitkeep
│   └── <slug>/…
└── _index.html              ← generated; .gitignored
```

### Follow-up task files

- `002-create-scaffold.md` — lay down the file/folder skeleton (stubs + `.gitignore` + `thumbnails/.gitkeep` + `refresh.cmd`).
- `003-parse-folders.md` — implement `parse_folders.sh`.
- `004-extract-thumbnails.md` — implement `extract_thumbnails.sh` (with slug + recursion).
- `005-generate-index.md` — implement `generate_index.sh` (nested `<details>`, `file:///` hrefs).
- `006-refresh.md` — implement `refresh.sh` with count-guard; wire `refresh.cmd`.
- `007-howto.md` — write `scripts/howto.md`.

Sequence is hard: each depends on the previous. Serial execution, no parallelism.

## Questions

_(resolved — see Decisions above)_
