#!/usr/bin/env bash
# generate_index.sh — render the static _index.html from scanned folders and thumbnails
#
# For each folder emitted by parse_folders.sh, emit a top-level
# <details open data-cat="<slug>"> section. For recurse=0 the section holds
# a single grid of the folder's direct-child .3mf files. For recurse=1 the
# walker recurses into the tree and emits a nested <details open> at every
# subdirectory that (directly or indirectly) contains at least one .3mf.
# Empty subdirectories are skipped.
#
# Cards link with absolute file:/// URIs (backslashes flipped to forward
# slashes, then percent-encoded). Thumbnails are referenced with a relative
# ./thumbnails/<slug>/<rel-subdir>/<base>.png path.
#
# CSS and the localStorage expand-state JS are copied unchanged from the
# reference implementation at
#   D:\3D\Space Monkey 3D Designs\scripts\generate_index.sh

set -u
cd "$(dirname "$0")/.."

out="_index.html"

# ---- helpers (copied unchanged from reference) ----------------------------
urlenc() { printf '%s' "$1" | sed 's/ /%20/g; s/#/%23/g; s/?/%3F/g'; }
htmlenc() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

# Slug formula — must match extract_thumbnails.sh exactly.
slugify() {
  local s="$1"
  s="${s//:/_}"
  s="${s//\\/_}"
  s="${s//\//_}"
  s="${s// /_}"
  s="${s//$'\t'/_}"
  printf '%s' "$s"
}

# Build a file:/// href from an absolute Windows-style path.
# 1) flip backslashes to forward slashes so they survive URL encoding
# 2) URL-encode (only space/#/? per reference urlenc)
file_href() {
  local p="${1//\\//}"
  printf 'file:///%s' "$(urlenc "$p")"
}

# ---- gather entries -------------------------------------------------------
mapfile -t entries < <(scripts/parse_folders.sh)
if (( ${#entries[@]} == 0 )); then
  echo "generate_index.sh: error: parse_folders.sh returned no entries" >&2
  exit 1
fi

# Grand total of .3mf files across all listed folders (for page meta line).
grand_total=0
for row in "${entries[@]}"; do
  [[ -z "$row" ]] && continue
  IFS=$'\t' read -r folder flag <<<"$row"
  [[ -z "$folder" ]] && continue
  [[ ! -d "$folder" ]] && continue
  if [[ "$flag" == "1" ]]; then
    n=$(find "$folder" -type f -name '*.3mf' 2>/dev/null | wc -l)
  else
    n=$(find "$folder" -maxdepth 1 -type f -name '*.3mf' 2>/dev/null | wc -l)
  fi
  grand_total=$((grand_total + n))
done

# ---- recursive walker -----------------------------------------------------
# Args:
#   $1 = current directory (absolute path, same form as $folder)
#   $2 = listed root folder
#   $3 = slug for this top-level listed folder
#   $4 = depth indent (unused, kept for future)
# Emits a <details open> for $1 if $1 (or any descendant) contains .3mf,
# otherwise emits nothing. Nested subsections recurse.
emit_section_recursive() {
  local dir="$1"
  local root="$2"
  local slug="$3"

  # Relative subdir under $root. Normalize separators for display/slug suffix.
  local rel="${dir#"$root"}"
  rel="${rel#[/\\]}"
  # Normalize all backslashes to forward slashes for relative paths.
  rel="${rel//\\//}"

  # Direct-child .3mf files in $dir (sorted).
  local files=()
  mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name '*.3mf' 2>/dev/null | LC_ALL=C sort)

  # Immediate subdirectories that contain at least one .3mf somewhere below.
  # Collect subdirs first (sorted), then filter those with 3mf descendants.
  local subdirs=() sub has_3mf
  mapfile -t subdirs < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort)

  local nonempty_subs=()
  for sub in "${subdirs[@]}"; do
    [[ -z "$sub" ]] && continue
    has_3mf=$(find "$sub" -type f -name '*.3mf' 2>/dev/null -print -quit)
    if [[ -n "$has_3mf" ]]; then
      nonempty_subs+=("$sub")
    fi
  done

  # If this dir has neither direct files nor any non-empty subdir, skip.
  if (( ${#files[@]} == 0 && ${#nonempty_subs[@]} == 0 )); then
    return 0
  fi

  # Section identity.
  # Top-level: data-cat=slug, summary=basename or full root path.
  # Nested: data-cat=slug/<rel>, summary=basename of $dir.
  local data_cat disp
  if [[ -z "$rel" ]]; then
    data_cat="$slug"
    # Use the full listed path as the display (more useful — shows D:\... root).
    disp="$root"
  else
    data_cat="$slug/$rel"
    disp="$(basename "$dir")"
  fi

  # Recursive .3mf count within $dir (for the section summary).
  local total
  total=$(find "$dir" -type f -name '*.3mf' 2>/dev/null | wc -l)

  local disp_enc cat_enc
  disp_enc=$(htmlenc "$disp")
  cat_enc=$(htmlenc "$data_cat")

  printf '<details open data-cat="%s"><summary>%s <span class="count">%d</span></summary>\n' \
    "$cat_enc" "$disp_enc" "$total"

  # Grid of direct-child cards (if any).
  if (( ${#files[@]} > 0 )); then
    printf '<div class="grid">\n'
    local f base enc_href enc_src name_enc rel_thumb
    for f in "${files[@]}"; do
      [[ -z "$f" ]] && continue
      base="$(basename "$f" .3mf)"
      enc_href=$(file_href "$f")
      if [[ -z "$rel" ]]; then
        rel_thumb="thumbnails/$slug/$base.png"
      else
        rel_thumb="thumbnails/$slug/$rel/$base.png"
      fi
      enc_src=$(urlenc "$rel_thumb")
      name_enc=$(htmlenc "$base")
      printf '  <a class="card" href="%s"><img src="%s" loading="lazy" alt=""><div class="name">%s</div></a>\n' \
        "$enc_href" "$enc_src" "$name_enc"
    done
    printf '</div>\n'
  fi

  # Nested subsections.
  for sub in "${nonempty_subs[@]}"; do
    emit_section_recursive "$sub" "$root" "$slug"
  done

  printf '</details>\n'
}

# Emit a flat (non-recursive) section for a listed folder.
emit_section_flat() {
  local dir="$1"
  local slug="$2"

  local files=()
  mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name '*.3mf' 2>/dev/null | LC_ALL=C sort)

  local disp_enc cat_enc
  disp_enc=$(htmlenc "$dir")
  cat_enc=$(htmlenc "$slug")

  printf '<details open data-cat="%s"><summary>%s <span class="count">%d</span></summary>\n' \
    "$cat_enc" "$disp_enc" "${#files[@]}"

  if (( ${#files[@]} > 0 )); then
    printf '<div class="grid">\n'
    local f base enc_href enc_src name_enc
    for f in "${files[@]}"; do
      [[ -z "$f" ]] && continue
      base="$(basename "$f" .3mf)"
      enc_href=$(file_href "$f")
      enc_src=$(urlenc "thumbnails/$slug/$base.png")
      name_enc=$(htmlenc "$base")
      printf '  <a class="card" href="%s"><img src="%s" loading="lazy" alt=""><div class="name">%s</div></a>\n' \
        "$enc_href" "$enc_src" "$name_enc"
    done
    printf '</div>\n'
  fi

  printf '</details>\n'
}

# ---- render ---------------------------------------------------------------
{
cat <<HEAD
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>3MF Explorer — Model Index</title>
<style>
  :root { color-scheme: dark light; }
  body { font-family: system-ui, sans-serif; margin: 20px; background: #111; color: #eee; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .meta { color: #888; font-size: 13px; margin-bottom: 20px; }
  details { margin-bottom: 12px; border: 1px solid #2a2a2a; border-radius: 8px; background: #161616; }
  summary { cursor: pointer; padding: 10px 14px; font-size: 15px; font-weight: 600; user-select: none; list-style: none; display: flex; align-items: center; gap: 8px; }
  summary::-webkit-details-marker { display: none; }
  summary::before { content: "▸"; color: #888; transition: transform 0.15s; display: inline-block; }
  details[open] > summary::before { transform: rotate(90deg); }
  summary:hover { background: #1f1f1f; }
  details[open] > summary { border-bottom: 1px solid #2a2a2a; }
  summary .count { color: #888; font-weight: normal; font-size: 13px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px; padding: 16px; }
  .card { background: #1c1c1c; border-radius: 8px; overflow: hidden; display: flex; flex-direction: column; color: inherit; text-decoration: none; }
  .card:hover { outline: 2px solid #6cf; }
  .card img { width: 100%; aspect-ratio: 1/1; object-fit: contain; background: #000; display: block; }
  .card .name { padding: 8px 10px; font-size: 13px; word-break: break-word; }
</style>
</head>
<body>
<h1>3MF Explorer</h1>
<div class="meta">$grand_total models — click a tile to open the .3mf file</div>
HEAD

for row in "${entries[@]}"; do
  [[ -z "$row" ]] && continue
  IFS=$'\t' read -r folder flag <<<"$row"
  [[ -z "$folder" ]] && continue

  if [[ ! -d "$folder" ]]; then
    echo "generate_index.sh: warning: listed folder does not exist, skipping: $folder" >&2
    continue
  fi

  slug="$(slugify "$folder")"

  if [[ "$flag" == "1" ]]; then
    emit_section_recursive "$folder" "$folder" "$slug"
  else
    emit_section_flat "$folder" "$slug"
  fi
done

cat <<'TAIL'
<script>
(function(){
  try {
    var els = document.querySelectorAll('details[data-cat]');
    for (var i = 0; i < els.length; i++) {
      var key = 'cat-open:' + els[i].dataset.cat;
      var v = localStorage.getItem(key);
      if (v === '0') els[i].open = false;
      else if (v === '1') els[i].open = true;
      els[i].addEventListener('toggle', function(e) {
        try { localStorage.setItem('cat-open:' + e.target.dataset.cat, e.target.open ? '1' : '0'); } catch (_) {}
      });
    }
  } catch (_) {}
})();
</script>
</body>
</html>
TAIL
} > "$out"

echo "Wrote $out ($(wc -c < "$out") bytes, $grand_total models)"
