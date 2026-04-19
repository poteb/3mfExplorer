# How to use 3mfExplorer

3mfExplorer scans one or more folders on disk — anywhere on your system —
for `.3mf` files, pulls the preview PNG out of each one, and builds a
static HTML contact sheet (`_index.html`) at the repo root. Clicking a
card opens the underlying `.3mf` in whatever application Windows has
registered for that extension (typically your slicer).

The list of folders to scan is not baked into the scripts — it lives in
`3mffolders.md` at the repo root, so the same install can span multiple
drives and project trees without copying files around.

## Configure `3mffolders.md`

One folder per line. Add `*` to the end of a line to recurse into
subfolders; omit it to scan only the folder's direct children. Blank
lines and lines starting with `#` are ignored.

```text
# Main library — scan every subfolder
D:\3D\Space Monkey 3D Designs\*

# Vendor packs, root only (don't dive into sample/source subdirs)
D:\3D\Pork 3D

# Work in progress on another drive
E:\Projects\WIP\*
```

The recurse marker is lenient: ` *`, `\*`, `/*`, or a bare `*` glued to
the path all work. Paths that don't exist on disk produce a warning but
don't stop the refresh — the other entries are still processed. An
empty or missing `3mffolders.md` aborts with an error.

## Run the refresh

Two equivalent options. Re-run whenever you add, remove, rename, or move
`.3mf` files.

**Option A — double-click `scripts/refresh.cmd`**
A console window opens, runs the pipeline, and pauses on completion so
you can read the output.

**Option B — from Git Bash**
Right-click in the repo folder in Explorer, choose **Git Bash Here**,
and run:

```bash
bash scripts/refresh.sh
```

The scripts `cd` to the repo root internally, so the current working
directory doesn't matter.

## Open the index

Double-click `_index.html` in Explorer. Each listed folder becomes a
top-level expandable section; with recurse enabled, every subdirectory
that contains at least one `.3mf` becomes a nested subsection. Empty
subdirectories are skipped. Click a card to open the corresponding
`.3mf` in your default app via a `file:///` URL. Your open/closed state
per section is saved in the browser's `localStorage`.

## Folder layout

Generated artifacts live at the repo root — not next to the source
folders. Source `.3mf` files are never modified or moved.

```
3mfExplorer/
├── 3mffolders.md              ← list of folders to scan
├── _index.html                ← generated contact sheet
├── thumbnails/                ← generated PNGs, one subtree per listed folder
│   └── <slug>/                  slug = abs path with :, \, /, whitespace → _
│       └── <relative-subdir>/
│           └── <basename>.png
└── scripts/
    ├── refresh.cmd
    ├── refresh.sh
    ├── parse_folders.sh
    ├── extract_thumbnails.sh
    ├── generate_index.sh
    └── howto.md               ← this file
```

Example slug: `D:\3D\Space Monkey 3D Designs` becomes
`D__3D_Space_Monkey_3D_Designs`.

## What the scripts do

| Script                  | Purpose                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------- |
| `refresh.cmd`           | Windows wrapper that invokes `refresh.sh` via `bash` and pauses on completion.                      |
| `refresh.sh`            | Orchestrator: runs extract, applies a count-guard, then regenerates `_index.html`.                  |
| `parse_folders.sh`      | Emits `<abs-path>\t<recurse-flag>` lines from `3mffolders.md`; aborts if the file has no entries.   |
| `extract_thumbnails.sh` | Wipes `thumbnails/` and extracts the embedded preview PNG from every `.3mf` into `thumbnails/<slug>/…`. |
| `generate_index.sh`     | Renders `_index.html` with one `<details>` section per listed folder, nested for recurse entries.   |

The refresh is safe to re-run. `thumbnails/` is wiped and rebuilt from
scratch each time, so renames and moves never leave orphans. If
extraction produces fewer PNGs than there are `.3mf` files, `refresh.sh`
aborts *before* touching `_index.html` — so a broken extract never
overwrites a working index with missing-image cards.

Preview paths tried inside each `.3mf` (first hit wins):
`Metadata/plate_1.png` → `Metadata/top_1.png` → `Metadata/plate_1_small.png`.

## Dependencies

Just **bash** and **unzip**, both of which ship with
[Git for Windows](https://git-scm.com/download/win). No Node, no Python,
no extra installers.

## Troubleshooting

**`unzip: command not found`**
You're running in a shell that doesn't ship `unzip`. Use Git Bash
(installed with Git for Windows) or run `scripts/refresh.cmd` from
Explorer — both resolve `unzip` automatically.

**`Files with no extractable thumbnail: …`**
That `.3mf` didn't contain a preview at any of the known paths
(`Metadata/plate_1.png`, `top_1.png`, `plate_1_small.png`). It was
probably exported by a slicer that doesn't embed previews. Open it in
your slicer, re-save it, and re-run the refresh.

**`ERROR: N thumbnails for M .3mf files (missing D). Refusing to rebuild _index.html …`**
The count-guard tripped: extraction produced fewer PNGs than the number
of `.3mf` files on disk. Usually a transient file lock (slicer still
holds a file) or antivirus scanning a freshly-saved file. Fix the
underlying issue and re-run. Your existing `_index.html` is untouched
until the next clean refresh.

**`parse_folders.sh: error: '3mffolders.md' not found`** or
**`… contains zero valid entries`**
Create `3mffolders.md` at the repo root and add at least one folder
line. Comments (`#`) and blank lines alone don't count.

**`warning: listed path does not exist: …`**
You listed a folder that isn't reachable (unmounted drive, typo, moved
project). Non-fatal — other entries still process. Fix or remove the
line in `3mffolders.md` to silence the warning.
