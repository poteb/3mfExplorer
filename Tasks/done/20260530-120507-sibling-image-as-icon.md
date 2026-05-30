# Sibling Image As Icon

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
When scanning for `.3mf` files, if a `.png` or `.jpg` image exists in the same folder with the same base name as the `.3mf` (e.g. `model.png` next to `model.3mf`), use that image as the icon/preview instead of extracting the embedded preview from the `.3mf`. Fall back to extracting from the `.3mf` only when no matching sibling image is present.

## Notes
- Implemented entirely in `scripts/extract_thumbnails.sh`. No change to `generate_index.sh` or other scripts was needed because the output path scheme is unchanged: the icon is still written to `thumbnails/<slug>/<rel>/<base>.png`, which `generate_index.sh` already references verbatim.
- Added a `copy_sibling_image()` helper that, for a given `<base>.3mf`, looks for a same-folder same-basename image and copies it to the `<base>.png` output. Candidate extensions tried in order: `.png`, `.PNG`, `.jpg`, `.JPG`, `.jpeg`, `.JPEG` (only the file must be non-empty).
- The per-file loop now tries `copy_sibling_image` first; only if there is no sibling does it fall back to `extract_one_preview` (the existing embedded-preview extraction). Files with neither are tallied as missing as before.
- Decision: a `.jpg` sibling is copied to a `.png` filename rather than converted. This avoids adding any image-conversion dependency (keeps the bash + unzip, no-extra-deps constraint). Browsers sniff image type by content (magic bytes), not by extension, so a JPEG served under a `.png` name still renders correctly in the static HTML.
- Summary line updated to report how many icons came from sibling images, e.g. `Extracted 4 / 4 thumbnails to ./thumbnails/ (3 from sibling images)`.
- Verification: `bash -n` syntax check passed. Built an isolated test repo with four fixture `.3mf` files (zips with an embedded `Metadata/plate_1.png`) plus siblings: `alpha.png`, `delta.PNG` (uppercase), `gamma.jpg`, and `beta` with no sibling. Ran `extract_thumbnails.sh` against it:
  - alpha → contents `SIBLING_PNG_ALPHA` (lowercase .png sibling used)
  - delta → contents `SIBLING_PNG_DELTA` (uppercase .PNG sibling used)
  - gamma → contents `SIBLING_JPG_GAMMA` (.jpg sibling used, written to .png path)
  - beta  → contents `EMBEDDED_PNG_BETA` (no sibling → fell back to embedded preview extraction)
  - Reported `Extracted 4 / 4 thumbnails (3 from sibling images)`. All cases correct.
- Did NOT commit — left working tree modified per task constraints.

## Questions
