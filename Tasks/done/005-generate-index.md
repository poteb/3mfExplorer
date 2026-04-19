# Generate Index

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Implement `scripts/generate_index.sh`. Writes `_index.html` at the repo root, with one top-level `<details open>` per listed folder and nested `<details open>` sections for each recursed subdirectory at any depth.

Behavior:
- `cd "$(dirname "$0")/.."` first.
- Call `parse_folders.sh` to get the `(path, recurse)` list.
- For each listed folder:
  - Top-level `<details open data-cat="<slug>"><summary>…</summary>…</details>` section. Summary shows the folder's display name (basename or the full path — pick the more useful one) and the `.3mf` count for that folder.
  - If recurse flag is `0`: single grid of cards for files directly in the folder.
  - If recurse flag is `1`: walk the tree; at each directory that contains at least one `.3mf`, emit a nested `<details open>` subsection. Subsections are nested to arbitrary depth, mirroring the folder structure. Empty directories are skipped.
- Each card: `<a class="card" href="<file:/// URL>"><img src="<thumbnails path>" loading="lazy" alt=""><div class="name">…</div></a>`.
- `href` is `file:///` + URL-encoded absolute path of the `.3mf`.
- `src` is the matching `thumbnails/<slug>/<relative-subpath>/<base>.png` path (relative, since `_index.html` sits next to `thumbnails/`).
- Copy the dark-theme CSS and the `localStorage` expand-state JS from the reference (`generate_index.sh`) unchanged, just swap the `<h1>` text.
- Abort with a clear error if `parse_folders.sh` returns no entries (should never happen — parse already aborts — but defensive).

Path encoding: reuse the `urlenc`/`htmlenc` helpers from the reference. For the `file:///` scheme, also convert `\` to `/` and handle the drive letter (`D:\foo` → `file:///D:/foo`).

Done when: opening `_index.html` in Chrome shows a correctly nested index with working thumbnail images and clicking a card opens the `.3mf` file.

## Notes

### Implementation

- CSS block, `urlenc`, `htmlenc`, and the `<script>` localStorage JS are copied verbatim from `D:\3D\Space Monkey 3D Designs\scripts\generate_index.sh`. Only the `<h1>` text changed (`Space Monkey 3D Designs` → `3MF Explorer`) and the `<title>` updated accordingly.
- Slug formula mirrors `extract_thumbnails.sh` exactly (`:`, `\`, `/`, spaces, tabs → `_`; no collapse), implemented inline as `slugify()` so the script stays dependency-free.
- Added a `file_href()` helper that flips `\` → `/` **before** URL-encoding so separators aren't percent-encoded (spaces become `%20`; path becomes `file:///D:/...`).
- Two emitters:
  - `emit_section_flat` — for recurse=0 entries, single grid of direct children.
  - `emit_section_recursive` — walks the tree. At each dir with any direct `.3mf` or any non-empty descendant, emits `<details open data-cat="<slug>[/<rel>]">`, then the direct-children grid (if any), then recurses into subdirs. Skips subtrees with zero `.3mf` anywhere below. Handles arbitrary depth.
- Summary text for top-level recursed sections uses the full listed path (`D:\3D\Space Monkey 3D Designs`) since that's more informative than the basename. Nested subsections use `basename`. Each `<summary>` shows the recursive `.3mf` count for that subtree.
- `data-cat` is unique per section: top-level uses the slug; nested uses `slug/rel/path` (so localStorage remembers each subsection independently).
- Sort: `find | LC_ALL=C sort` for deterministic output.

### Real-run result (3mffolders.md with Space Monkey, Pork 3D, lov3d all recursive)

```
Wrote _index.html (29277 bytes, 101 models)
```

- 101 `<a class="card">` anchors — matches 101 thumbnails (task 004) and 68+19+14 source count.
- 11 `<details>` open / 11 close — balanced. 3 top-level (one per listed folder) + 8 Space Monkey subcategories (Animals, Animals with Attitude, Dolls, Fantasy, Greek Mythology, Misc, Patchwork, Xmas).
- All 11 `data-cat` slugs unique.
- Perl-based verification walked every `<img src="...">` and every `href="file:///..."`, URL-decoded, and stat'd the filesystem: **101/101 thumbnails resolve, 101/101 .3mf hrefs resolve**. No broken references.
- Top-level summaries show full path + recursive count: `D:\3D\Space Monkey 3D Designs (68)`, `D:\3D\Pork 3D (19)`, `D:\3D\lov3d (14)`.

### Sample (href, src, name) per listed folder

1. Space Monkey 3D Designs / Animals:
   - href: `file:///D:/3D/Space%20Monkey%203D%20Designs/Animals/Capybara%20Dragon.3mf`
   - src:  `thumbnails/D__3D_Space_Monkey_3D_Designs/Animals/Capybara%20Dragon.png`
   - name: `Capybara Dragon`
2. Pork 3D (flat):
   - href: `file:///D:/3D/Pork%203D/2x1+Building+Brick+Storage+by+Pork3D.3mf`
   - src:  `thumbnails/D__3D_Pork_3D/2x1+Building+Brick+Storage+by+Pork3D.png`
   - name: `2x1+Building+Brick+Storage+by+Pork3D`
3. lov3d (flat):
   - href: `file:///D:/3D/lov3d/3+heart+family.3mf`
   - src:  `thumbnails/D__3D_lov3d/3+heart+family.png`
   - name: `3+heart+family`

All three spot-check files exist on disk, as do their thumbnails.

### Notes / caveats

- `urlenc` intentionally only encodes space, `#`, `?` (matching reference). Characters like `&`, `+`, `'` are left as-is in the href attribute. Browsers handle this fine for `file:///` URIs. Display names are HTML-encoded via `htmlenc` (e.g. `&` → `&amp;`), so display is safe even when the filename literally contains an ampersand (e.g. lov3d's `Modern+Ribbed+&+Fuzzy+Easter+Eggs`).
- Could not open a live browser from this agent session, but did perform the spec's `grep`-level structural sanity check (nested `<details>` balance, unique `data-cat`, every `src`/`href` resolves to a real file).

## Questions
