#!/usr/bin/env bash
# refresh.sh — orchestrator: parse folders, extract thumbnails, regenerate _index.html
#
# Flow (mirrors the reference at D:\3D\Space Monkey 3D Designs\scripts\refresh.sh):
#   1. cd to repo root so all subscripts operate on consistent relative paths.
#   2. Run extract_thumbnails.sh; bail on non-zero.
#   3. Count-guard: re-read parse_folders.sh output, tally expected .3mf
#      count across all entries (maxdepth 1 for flag=0, unlimited for flag=1),
#      then count PNGs under thumbnails/ (excluding .gitkeep). If actual is
#      less than expected, print a clear stderr error and exit 1 *without*
#      running generate_index.sh — the existing _index.html stays intact.
#   4. Run generate_index.sh.

set -u
cd "$(dirname "$0")/.."

# --- step 1: extract thumbnails ---
bash scripts/extract_thumbnails.sh
extract_rc=$?
if (( extract_rc != 0 )); then
  echo "refresh.sh: error: extract_thumbnails.sh exited with $extract_rc — aborting." >&2
  exit 1
fi

# --- step 2: count-guard ---
# Expected count: sum .3mf files across every folder emitted by parse_folders.sh,
# respecting each entry's recurse flag.
expected=0
while IFS=$'\t' read -r folder flag; do
  [[ -z "$folder" ]] && continue
  if [[ ! -d "$folder" ]]; then
    # parse_folders.sh already warned; keep expected accurate by skipping.
    continue
  fi
  if [[ "$flag" == "1" ]]; then
    n=$(find "$folder" -type f -name '*.3mf' 2>/dev/null | wc -l)
  else
    n=$(find "$folder" -maxdepth 1 -type f -name '*.3mf' 2>/dev/null | wc -l)
  fi
  expected=$((expected + n))
done < <(scripts/parse_folders.sh)

# Actual count: every .png anywhere under thumbnails/. .gitkeep is not a .png
# so no explicit exclusion is needed, but filter defensively just in case.
if [[ -d thumbnails ]]; then
  actual=$(find thumbnails -type f -name '*.png' 2>/dev/null | wc -l)
else
  actual=0
fi

if (( actual < expected )); then
  delta=$((expected - actual))
  echo "" >&2
  echo "refresh.sh: ERROR: $actual thumbnails for $expected .3mf files (missing $delta)." >&2
  echo "Refusing to rebuild _index.html (would have broken images)." >&2
  echo "Resolve the extract issue above and re-run." >&2
  exit 1
fi

# --- step 3: regenerate _index.html ---
bash scripts/generate_index.sh
gen_rc=$?
if (( gen_rc != 0 )); then
  echo "refresh.sh: error: generate_index.sh exited with $gen_rc." >&2
  exit 1
fi
