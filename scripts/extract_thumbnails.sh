#!/usr/bin/env bash
# extract_thumbnails.sh — extract preview PNGs from .3mf files into thumbnails/
#
# For each folder emitted by parse_folders.sh, iterate its .3mf files (direct
# children if recurse flag is 0, or every depth if 1) and copy the embedded
# preview PNG out of the .3mf archive into
#   thumbnails/<slug>/<relative-subdir>/<basename>.png
# where <slug> is the sanitized absolute path of the listed folder
# (D:\3D\Space Monkey 3D Designs -> D__3D_Space_Monkey_3D_Designs).
#
# Preview paths tried (first match wins, copied from the reference impl
# at D:\3D\Space Monkey 3D Designs\scripts\extract_thumbnails.sh):
#   Metadata/plate_1.png -> Metadata/top_1.png -> Metadata/plate_1_small.png
#
# Does not `set -e` — individual failures are tallied, not fatal.

set -u
cd "$(dirname "$0")/.."

# Wipe and recreate thumbnails/ so renames/moves don't leave orphans.
rm -rf thumbnails
mkdir -p thumbnails
touch thumbnails/.gitkeep

# Sanitize a listed-folder absolute path into a filesystem-safe slug.
# Replaces ':', '\', '/', and any whitespace (space/tab/etc.) with '_'.
# Collapses runs of '_' so "D:\3D\..." doesn't produce "D::\\" artifacts
# (only the exact chars from the spec are replaced — no collapse, per task
# example 'D:\3D\Space Monkey 3D Designs' -> 'D__3D_Space_Monkey_3D_Designs').
slugify() {
  local s="$1"
  # Replace : \ / and whitespace chars with _ (one-for-one).
  # Use Bash's global pattern substitution.
  s="${s//:/_}"
  s="${s//\\/_}"
  s="${s//\//_}"
  # Whitespace: spaces, tabs. Handle each class.
  s="${s// /_}"
  s="${s//$'\t'/_}"
  printf '%s' "$s"
}

# If a sibling image (same folder, same base name as the .3mf) exists, copy
# it to $out and return 0. Tries .png first, then .jpg/.jpeg (case-insensitive
# extension). The output is always written to the <base>.png path so the rest
# of the pipeline (generate_index.sh references <base>.png) is unchanged — a
# JPEG copied under a .png name still renders, since browsers sniff image bytes
# by content, not extension. No image conversion tool is required (keeps the
# bash + unzip, no-extra-deps constraint). Returns 1 if no sibling is found.
copy_sibling_image() {
  local src="$1" out="$2"
  local dir base candidate
  dir="$(dirname "$src")"
  base="$(basename "$src" .3mf)"
  for candidate in \
    "$dir/$base.png" "$dir/$base.PNG" \
    "$dir/$base.jpg" "$dir/$base.JPG" \
    "$dir/$base.jpeg" "$dir/$base.JPEG"; do
    if [ -f "$candidate" ] && [ -s "$candidate" ]; then
      if cp -f "$candidate" "$out" 2>/dev/null; then
        return 0
      fi
    fi
  done
  return 1
}

# Try each candidate preview path; return 0 on first success (non-empty
# extracted bytes written to $out), 1 if none of the candidates produced
# a non-empty payload.
extract_one_preview() {
  local src="$1" out="$2"
  local candidate
  for candidate in "Metadata/plate_1.png" "Metadata/top_1.png" "Metadata/plate_1_small.png"; do
    if unzip -p "$src" "$candidate" > "$out" 2>/dev/null && [ -s "$out" ]; then
      return 0
    fi
  done
  # Clean up empty file left by last failed attempt.
  rm -f "$out"
  return 1
}

count=0
sibling_count=0
missing=0
missing_files=()

# Iterate parse_folders.sh output. The script prints tab-separated
# "<abs-path>\t<flag>" lines.
while IFS=$'\t' read -r folder flag; do
  # Defensive: skip any line that lacks the separator or is blank.
  [[ -z "$folder" ]] && continue

  if [[ ! -d "$folder" ]]; then
    echo "extract_thumbnails.sh: warning: listed folder does not exist, skipping: $folder" >&2
    continue
  fi

  slug="$(slugify "$folder")"

  # Build the list of .3mf files under $folder.
  # flag=0 -> only direct children; flag=1 -> recurse unlimited.
  if [[ "$flag" == "1" ]]; then
    mapfile -t files < <(find "$folder" -type f -name '*.3mf' 2>/dev/null)
  else
    mapfile -t files < <(find "$folder" -maxdepth 1 -type f -name '*.3mf' 2>/dev/null)
  fi

  for src in "${files[@]}"; do
    [[ -z "$src" ]] && continue

    # Compute path relative to the listed folder.
    # Both $folder and $src use the same root form (backslash Windows path
    # from parse_folders.sh; find echoes children appended with '/').
    rel="${src#"$folder"}"
    # Strip leading path separator ('/' or '\').
    rel="${rel#[/\\]}"

    # Split into relative subdir and basename.
    base="$(basename "$rel" .3mf)"
    subdir="$(dirname "$rel")"

    if [[ "$subdir" == "." || -z "$subdir" ]]; then
      out_dir="thumbnails/$slug"
    else
      out_dir="thumbnails/$slug/$subdir"
    fi

    mkdir -p "$out_dir"
    out="$out_dir/$base.png"

    # Prefer a sibling image (model.png / model.jpg next to model.3mf) over the
    # .3mf's embedded preview. Fall back to extraction only when none exists.
    if copy_sibling_image "$src" "$out"; then
      count=$((count + 1))
      sibling_count=$((sibling_count + 1))
    elif extract_one_preview "$src" "$out"; then
      count=$((count + 1))
    else
      missing=$((missing + 1))
      missing_files+=("$src")
    fi
  done
done < <(scripts/parse_folders.sh)

total=$((count + missing))
echo "Extracted $count / $total thumbnails to ./thumbnails/ ($sibling_count from sibling images)"
if [[ "$missing" -gt 0 ]]; then
  echo "Files with no extractable thumbnail ($missing):"
  printf '  %s\n' "${missing_files[@]}"
fi
