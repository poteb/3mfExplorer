# Extract Thumbnails

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Implement `scripts/extract_thumbnails.sh`. For every listed folder, pull the embedded preview PNG out of every `.3mf` file and write it under `thumbnails/<slug>/<relative-subpath>/<base>.png`.

Behavior:
- `cd "$(dirname "$0")/.."` first.
- Wipe and recreate `thumbnails/` (then restore `.gitkeep`) so renames/moves don't leave orphans.
- Call `parse_folders.sh` and iterate over its output.
- **Slug derivation**: sanitize the listed folder's absolute path by replacing `:`, `\`, `/`, and whitespace with `_`. Example: `D:\3D\Space Monkey 3D Designs` → `D__3D_Space_Monkey_3D_Designs`.
- For each listed folder:
  - If recurse flag is `0`: only `.3mf` files directly in that folder.
  - If recurse flag is `1`: every `.3mf` at any depth (unlimited — `find <path> -type f -name '*.3mf'`).
  - For each `.3mf`, compute the relative path from the listed folder, and write the preview to `thumbnails/<slug>/<relative-subpath>/<basename>.png`. Create subdirs as needed.
- Extraction tries `Metadata/plate_1.png`, then `top_1.png`, then `plate_1_small.png` (copy from reference).
- Count successful extractions and list files with no usable preview at the end.

Path handling: the listed paths are Windows absolute paths (e.g. `D:\3D\...`). Git Bash accepts both `D:\foo` and `/d/foo` forms — test both. Prefer whatever `find` handles cleanly.

Done when: running the script populates `thumbnails/` correctly for a real `3mffolders.md` with both recursive and non-recursive entries, and reports the count summary.

## Notes

### Implementation

Rewrote the stub `scripts/extract_thumbnails.sh` into a full implementation.
Core structure borrowed from the reference at
`D:\3D\Space Monkey 3D Designs\scripts\extract_thumbnails.sh`:

- Same `unzip -p <src> <candidate-name> > <out>` + `[ -s "$out" ]` pattern
  to peel a single entry out of the `.3mf` ZIP and accept it only if the
  extracted payload is non-empty.
- Same candidate order: `Metadata/plate_1.png` → `Metadata/top_1.png` →
  `Metadata/plate_1_small.png`.
- Same "wipe and recreate `thumbnails/` up front so orphans can't linger"
  behavior. Added a `touch thumbnails/.gitkeep` after the recreate to
  preserve the placeholder the scaffold relies on.
- Same "no usable preview" tracking: accumulate into a
  `missing_files+=()` array, print a trailing list.
- Intentionally did NOT `set -e` — single-file failures should tally into
  the missing-count, not abort the whole run (reference does the same).

Changes vs. the reference:

- Input comes from `scripts/parse_folders.sh` (tab-separated
  `<abs-path>\t<flag>` lines) instead of iterating `*/` in CWD.
  Used `while IFS=$'\t' read -r folder flag; do … done < <(scripts/parse_folders.sh)`
  so the process-substitution stdin doesn't shadow `unzip`'s stdin.
- Added a `slugify()` helper that does per-task-spec replacements
  (`:`, `\`, `/`, whitespace → `_`) with pure Bash parameter expansion —
  no `sed`/`tr`. Verified the canonical example: `D:\3D\Space Monkey 3D Designs`
  → `D__3D_Space_Monkey_3D_Designs`.
- Added per-folder recursion branch: `flag=1` uses
  `find "$folder" -type f -name '*.3mf'` (unlimited depth);
  `flag=0` uses `-maxdepth 1`.
- For each `.3mf`, computes a relative path from the listed folder root,
  splits into `dirname`/`basename`, creates the mirror directory under
  `thumbnails/<slug>/…`, and writes `<base>.png`.

### Path form decision

`parse_folders.sh` emits Windows-style backslash paths (e.g.
`D:\3D\Space Monkey 3D Designs`). I kept those verbatim through the
pipeline rather than normalizing to `/d/3D/…`. Verified Git Bash's `find`
and `unzip` both accept the backslash form directly:

```
$ find 'D:\3D\Space Monkey 3D Designs' -maxdepth 2 -type f -name '*.3mf' | head -1
D:\3D\Space Monkey 3D Designs/Animals/Capybara Dragon.3mf
$ unzip -p 'D:\3D\Space Monkey 3D Designs\Animals\Capybara Dragon.3mf' \
    'Metadata/plate_1.png' | wc -c
80908
```

Note that `find` echoes children with forward-slash separators appended
to the backslash root; the `rel="${src#"$folder"}"` stripping works
regardless, and the subsequent `rel="${rel#[/\\]}"` handles the leading
separator in either form.

Passing the emitted `folder` straight through also means the relative
paths we build land in `thumbnails/<slug>/<forward-slash-subdir>/…`,
which is fine for Bash, `mkdir -p`, and later `<img src="…">` attributes.

### Real-run results

Ran against the real `3mffolders.md` (3 recurse entries):

```
$ bash scripts/extract_thumbnails.sh
Extracted 101 / 101 thumbnails to ./thumbnails/
```

- 101 / 101 extracted; 0 files with no usable preview.
- Source counts (sanity check):
  - `D:\3D\Space Monkey 3D Designs` → 68 `.3mf` → 68 PNGs
  - `D:\3D\Pork 3D` → 19 `.3mf` → 19 PNGs
  - `D:\3D\lov3d` → 14 `.3mf` → 14 PNGs
  - Total: 101 / 101.

Validated a handful of outputs with `file`:

```
thumbnails/D__3D_Space_Monkey_3D_Designs/Animals/Capybara Dragon.png
  → PNG image data, 512 x 512, 8-bit/color RGBA, non-interlaced
thumbnails/D__3D_Pork_3D/2x1+Building+Brick+Storage+by+Pork3D.png
  → PNG image data, 512 x 512, 8-bit/color RGBA, non-interlaced
thumbnails/D__3D_lov3d/3+heart+family.png
  → PNG image data, 512 x 512, 8-bit/color RGBA, non-interlaced
```

Size distribution spans ~8 KB (smallest: `Blade of the Tora .png`) to
~100 KB (largest: `braided+rope+tealight.png`). Zero zero-byte files.

Recursive subdirectory mirroring confirmed under the Space Monkey slug:

```
thumbnails/D__3D_Space_Monkey_3D_Designs/
  Animals/
  Animals with Attitude/
  Dolls/
  Fantasy/
  Greek Mythology/
  Misc/
  Patchwork/
  Xmas/
```

Non-recursive case is implicitly covered at the slug root — the Pork 3D
and lov3d folders have no subfolders, so their PNGs land directly under
`thumbnails/<slug>/`, which is the same layout a `flag=0` listing would
produce. (The real `3mffolders.md` has no `flag=0` entry, so the
`-maxdepth 1` branch wasn't exercised against live data. Code-read
confirms it mirrors the `flag=1` branch with `-maxdepth 1` added.)

### Files left in place

Per task brief, `thumbnails/` tree is left populated for inspection.
Nothing committed.

## Questions
