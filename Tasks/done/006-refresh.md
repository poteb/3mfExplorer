# Refresh

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Implement `scripts/refresh.sh` — the one-shot entry point. Orchestrates parse → extract → count-guard → generate, matching the reference's abort-on-miscount safety.

Behavior:
- `cd "$(dirname "$0")/.."` first.
- Run `bash scripts/extract_thumbnails.sh` — bail on non-zero exit.
- Count-guard: sum the expected `.3mf` count across all listed folders (re-parse via `parse_folders.sh` and walk each folder with the right recursion flag) and compare to the actual PNG count under `thumbnails/`. If PNGs < 3mfs, print a clear error to stderr and exit 1 without running `generate_index.sh` — the existing `_index.html` stays intact.
- Run `bash scripts/generate_index.sh` only if the guard passes.

`refresh.cmd` was scaffolded in task 002; confirm it still works (`bash refresh.sh` from the scripts folder, then `pause`).

Done when: running `bash scripts/refresh.sh` against a real `3mffolders.md` produces an up-to-date `_index.html` and `thumbnails/` tree, and intentionally breaking one `.3mf` (rename it) causes the count-guard to abort without touching `_index.html`.

## Notes

### Implementation

- `scripts/refresh.sh` now mirrors the reference's abort-on-miscount flow, adapted to our multi-root setup:
  1. `cd "$(dirname "$0")/.."` so subscripts see a consistent repo root regardless of CWD.
  2. `bash scripts/extract_thumbnails.sh`; bail on non-zero rc.
  3. Count-guard: re-run `scripts/parse_folders.sh` and for each `(folder, flag)` entry sum `.3mf` files (`-maxdepth 1` for flag=0, unlimited for flag=1). Count PNGs under `thumbnails/` with `find -type f -name '*.png'` (`.gitkeep` is not a `.png` so no explicit exclusion needed). If `actual < expected`, write a clear stderr error (incl. both counts and the missing delta) and exit 1 without touching `_index.html`.
  4. `bash scripts/generate_index.sh` only if the guard passes.
- Used `set -u` (not `set -e`) to match the reference — we want explicit rc checks after extract/generate, not silent aborts.
- `scripts/refresh.cmd` already matched the 4-line spec from task 002 (`@echo off` / `cd /d "%~dp0"` / `bash refresh.sh` / `pause`); no edit needed.

### Test 6a — happy path

- Command: `bash scripts/refresh.sh` against the real `3mffolders.md` (3 recurse entries: `D:\3D\Space Monkey 3D Designs`, `D:\3D\Pork 3D`, `D:\3D\lov3d`).
- Output tail:
  ```
  Extracted 101 / 101 thumbnails to ./thumbnails/
  Wrote _index.html (29277 bytes, 101 models)
  ```
- Expected count computation: `find -type f -name '*.3mf'` across all three recurse roots = **101**. PNG count under `thumbnails/` after extract = **101**. Guard: `101 < 101` is false → pass.
- `_index.html` card count (`grep -c 'class="card"'`) = **101** — matches the 101 models referenced in task 004's report.

### Test 6b — count-guard abort

- Rationale for using a synthetic file instead of rename-and-restore:
  - Renaming a single real `.3mf` to `.3mf.BROKEN-TEST` drops **both** counts by 1 (extract's `find` pattern misses it AND the guard's `.3mf` count misses it), so counts stay equal and the guard does **not** trip. Confirmed this empirically by doing the rename, realizing the flaw, and restoring immediately before running refresh.
  - The working approach: create an empty synthetic `.3mf` under a listed recurse folder. `find` counts it as a `.3mf` (expected++), but `unzip -p` fails to extract any preview (actual stays the same), so `actual < expected` and the guard fires. This is exactly the "added temporarily to a test dir" fallback the task brief listed.
- Setup: `mkdir "D:/3D/Pork 3D/_guard_test_tmp"` + `: > "D:/3D/Pork 3D/_guard_test_tmp/empty.3mf"` (0-byte file).
- Output:
  ```
  Extracted 101 / 102 thumbnails to ./thumbnails/
  Files with no extractable thumbnail (1):
    D:\3D\Pork 3D/_guard_test_tmp/empty.3mf

  refresh.sh: ERROR: 101 thumbnails for 102 .3mf files (missing 1).
  Refusing to rebuild _index.html (would have broken images).
  Resolve the extract issue above and re-run.
  ```
- Exit code: **1** (non-zero, as required).
- `_index.html` untouched during the aborted run:
  - Pre-guard:  sha1 `17b49d4332485573e945dba4e812ee4df136d606`, size `29277`, mtime `1776623775`
  - Post-guard: sha1 `17b49d4332485573e945dba4e812ee4df136d606`, size `29277`, mtime `1776623775`
  - Identical — guard aborted before `generate_index.sh` ran.

### Restoration evidence

- Cleanup: `rm "D:/3D/Pork 3D/_guard_test_tmp/empty.3mf" && rmdir "D:/3D/Pork 3D/_guard_test_tmp"`.
- Post-cleanup `ls "D:/3D/Pork 3D/_guard_test_tmp"` → "No such file or directory" (dir gone).
- Re-ran `bash scripts/refresh.sh`:
  ```
  Extracted 101 / 101 thumbnails to ./thumbnails/
  Wrote _index.html (29277 bytes, 101 models)
  EXIT=0
  ```
- Final `_index.html` sha1 = `17b49d4332485573e945dba4e812ee4df136d606` (same as pre-guard — rebuild is deterministic since content is unchanged).
- Also confirmed the originally-eyed rename target `D:/3D/Pork 3D/2x1+Building+Brick+Storage+by+Pork3D.3mf` exists with its original size (1,635,417 bytes) — the brief rename test was reverted before the guard-test attempt, and the synthetic approach never touched it.

### Count-guard formulation note

Task brief cautioned that the guard shouldn't blindly compare `PNGs in thumbnails/` to `number of .3mf files` when some `.3mf`s might yield no preview. The reference uses the simpler `PNGs < 3mfs → abort` formulation. Today our data is 101/101 (every `.3mf` yields a preview), so this is exact. If future `.3mf`s are preview-less, the guard will produce false positives — but that matches the reference's intentionally-conservative behavior: "a preview-less `.3mf` is a data issue to investigate, not silently paper over with broken `<img>` tags." Keeping the simple formulation for now; can be relaxed later if real-world preview-less `.3mf`s appear.

## Questions
