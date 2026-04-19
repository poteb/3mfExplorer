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
  local depth="${4:-0}"

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

  printf '<details open data-cat="%s" data-depth="%d"><summary>%s <span class="count">%d</span></summary>\n' \
    "$cat_enc" "$depth" "$disp_enc" "$total"

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
    emit_section_recursive "$sub" "$root" "$slug" $((depth + 1))
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

  printf '<details open data-cat="%s" data-depth="0"><summary>%s <span class="count">%d</span></summary>\n' \
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
# ---- depth-color palette (Material Design 100 pastels) --------------------
# Depth-indexed left-border stripe accent. Cycles mod palette length.
palette=(
  "#F8BBD0"  # Pink 100       — depth 0
  "#C8E6C9"  # Green 100      — depth 1
  "#C5CAE9"  # Indigo 100     — depth 2
  "#B2DFDB"  # Teal 100       — depth 3
  "#E1BEE7"  # Purple 100     — depth 4
  "#FFECB3"  # Amber 100      — depth 5
)
palette_len=${#palette[@]}
depth_css=""
for d in {0..10}; do
  color="${palette[$((d % palette_len))]}"
  depth_css+="  details[data-depth=\"$d\"] { border-left: 4px solid $color; }"$'\n'
done

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
$depth_css
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
  /* search bar */
  .searchbar { position: sticky; top: 0; z-index: 20; background: #111; border-bottom: 1px solid #2a2a2a; margin: -20px -20px 12px; padding: 10px 20px; display: flex; align-items: center; gap: 12px; }
  .searchbar h1 { flex: 0 0 auto; }
  .searchbar .search-wrap { position: relative; flex: 1 1 auto; max-width: 520px; }
  #q { width: 100%; box-sizing: border-box; background: #1c1c1c; border: 1px solid #2a2a2a; color: #eee; font: inherit; font-size: 14px; padding: 8px 32px 8px 12px; border-radius: 6px; outline: none; }
  #q:focus { border-color: #6cf; }
  #q-clear { position: absolute; right: 6px; top: 50%; transform: translateY(-50%); background: transparent; border: none; color: #888; cursor: pointer; font-size: 18px; line-height: 1; padding: 4px 8px; border-radius: 4px; }
  #q-clear:hover { color: #eee; }
  #q-clear:focus-visible { outline: 2px solid #6cf; outline-offset: 1px; color: #eee; }
  #q-clear[hidden] { display: none; }
  #results { position: absolute; left: 0; right: 0; top: calc(100% + 4px); background: #161616; border: 1px solid #2a2a2a; border-radius: 8px; max-height: 60vh; overflow-y: auto; box-shadow: 0 8px 24px rgba(0,0,0,0.5); z-index: 30; }
  #results[hidden] { display: none; }
  .result { display: flex; align-items: center; gap: 10px; padding: 6px 10px; color: inherit; text-decoration: none; border-bottom: 1px solid #1f1f1f; }
  .result:last-child { border-bottom: none; }
  .result:hover { background: #1f1f1f; }
  .result.active { background: #243140; box-shadow: inset 3px 0 0 #6cf; }
  .result img { width: 48px; height: 48px; flex: 0 0 48px; object-fit: contain; background: #000; border-radius: 4px; }
  .result .txt { display: flex; flex-direction: column; min-width: 0; }
  .result .crumb { font-size: 11px; color: #888; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .result .rname { font-size: 13px; color: #eee; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .result.empty { color: #888; font-style: italic; padding: 10px 14px; cursor: default; }
</style>
</head>
<body>
<div class="searchbar">
  <h1>3MF Explorer</h1>
  <div class="search-wrap">
    <input type="search" id="q" placeholder="Search…" autocomplete="off" spellcheck="false">
    <button type="button" id="q-clear" aria-label="Clear search" hidden>&times;</button>
    <div id="results" hidden></div>
  </div>
</div>
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
    emit_section_recursive "$folder" "$folder" "$slug" 0
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

// --- search ---
document.addEventListener('DOMContentLoaded', function(){
  var input = document.getElementById('q');
  var panel = document.getElementById('results');
  var clearBtn = document.getElementById('q-clear');
  if (!input || !panel) return;

  // Build the index: walk every card, derive breadcrumb from ancestor <details>.
  function stripCount(s) {
    // Summary text is "Folder Name NN" where NN is the trailing count span.
    // We already strip the span's text below, but handle any " (N)" style too.
    return s.replace(/\s+\(\d+\)\s*$/, '').replace(/\s+\d+\s*$/, '').trim();
  }
  function summaryText(details) {
    var sum = details.querySelector(':scope > summary');
    if (!sum) return '';
    // Clone and drop any .count span so trailing numeric count is removed.
    var c = sum.cloneNode(true);
    var counts = c.querySelectorAll('.count');
    for (var i = 0; i < counts.length; i++) counts[i].remove();
    return stripCount((c.textContent || '').trim());
  }
  function breadcrumbFor(el) {
    var parts = [];
    var node = el.parentNode;
    while (node && node !== document.body) {
      if (node.tagName === 'DETAILS') {
        var t = summaryText(node);
        if (t) parts.unshift(t);
      }
      node = node.parentNode;
    }
    return parts.join(' / ');
  }

  var cards = document.querySelectorAll('a.card');
  var index = [];
  for (var i = 0; i < cards.length; i++) {
    var card = cards[i];
    var nameEl = card.querySelector('.name');
    var img = card.querySelector('img');
    var name = nameEl ? (nameEl.textContent || '').trim() : '';
    index.push({
      name: name,
      lname: name.toLowerCase(),
      href: card.getAttribute('href') || '',
      thumb: img ? (img.getAttribute('src') || '') : '',
      crumb: breadcrumbFor(card)
    });
  }

  // Keyboard-nav state. -1 means no row is active.
  var activeIndex = -1;

  function rowNodes() {
    return panel.querySelectorAll('a.result');
  }

  function applyActive() {
    var rows = rowNodes();
    for (var i = 0; i < rows.length; i++) {
      if (i === activeIndex) rows[i].classList.add('active');
      else rows[i].classList.remove('active');
    }
  }

  function render(q) {
    panel.innerHTML = '';
    if (!q) { panel.hidden = true; activeIndex = -1; return; }
    var matches = [];
    for (var i = 0; i < index.length; i++) {
      if (index[i].lname.indexOf(q) !== -1) matches.push(index[i]);
    }
    if (matches.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'result empty';
      empty.textContent = 'No matches';
      panel.appendChild(empty);
    } else {
      for (var j = 0; j < matches.length; j++) {
        var m = matches[j];
        var a = document.createElement('a');
        a.className = 'result';
        a.href = m.href;
        var im = document.createElement('img');
        im.src = m.thumb;
        im.loading = 'lazy';
        im.alt = '';
        var txt = document.createElement('div');
        txt.className = 'txt';
        var cr = document.createElement('div');
        cr.className = 'crumb';
        cr.textContent = m.crumb;
        var nm = document.createElement('div');
        nm.className = 'rname';
        nm.textContent = m.name;
        txt.appendChild(cr);
        txt.appendChild(nm);
        a.appendChild(im);
        a.appendChild(txt);
        panel.appendChild(a);
      }
    }
    panel.hidden = false;
    // After (re)rendering, highlight the first real result (if any) so Enter
    // always opens something useful. "No matches" placeholder is not a row.
    var rows = rowNodes();
    activeIndex = rows.length > 0 ? 0 : -1;
    applyActive();
  }

  // Clear the field, hide the panel, reset keyboard-active index, and return
  // focus to the input. Shared between the × button click and the Escape key
  // so both paths do identical work.
  function clearSearch() {
    input.value = '';
    panel.hidden = true;
    panel.innerHTML = '';
    activeIndex = -1;
    if (clearBtn) clearBtn.hidden = true;
    input.focus();
  }

  // Hide the results panel WITHOUT clearing the query text. Used by the
  // outside-click dismiss (task 012). Preserves panel.innerHTML and
  // activeIndex so that refocusing the input re-shows the same list with
  // the same highlighted row — feels like the panel just peeked back.
  function hideResults() {
    panel.hidden = true;
  }

  // Re-show the results panel for the current query (task 012). Called on
  // input focus (click or Tab). If the query is empty, leaves the panel
  // hidden — same behavior as the debounced input handler with an empty
  // query. Re-renders from scratch so the list reflects any DOM drift
  // (there shouldn't be any, but cheap insurance).
  function showResults() {
    var q = input.value.trim().toLowerCase();
    if (!q) { panel.hidden = true; return; }
    render(q);
  }

  var t = null;
  input.addEventListener('input', function(){
    var q = input.value.trim().toLowerCase();
    if (clearBtn) clearBtn.hidden = input.value.length === 0;
    if (t) clearTimeout(t);
    t = setTimeout(function(){ render(q); }, 100);
  });
  if (clearBtn) {
    clearBtn.addEventListener('click', function(){
      clearSearch();
    });
  }
  // Keyboard nav: ArrowDown/ArrowUp walk the result rows (wrap-around), Enter
  // opens the active row, Escape clears the field and hides the panel
  // (delegates to clearSearch() so click-× and Escape stay in lockstep).
  input.addEventListener('keydown', function(e){
    if (e.key === 'Escape') {
      clearSearch();
      return;
    }
    if (panel.hidden) return;
    var rows = rowNodes();
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (rows.length === 0) return;
      activeIndex = (activeIndex + 1) % rows.length;
      applyActive();
      rows[activeIndex].scrollIntoView({block: 'nearest'});
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (rows.length === 0) return;
      activeIndex = (activeIndex - 1 + rows.length) % rows.length;
      applyActive();
      rows[activeIndex].scrollIntoView({block: 'nearest'});
    } else if (e.key === 'Enter') {
      if (rows.length === 0) return;
      e.preventDefault();
      var idx = activeIndex < 0 ? 0 : activeIndex;
      window.location.href = rows[idx].href;
    }
  });
  // Mouse hover does NOT update the keyboard-active index — hover and
  // keyboard-active are independent states (hover uses :hover; keyboard
  // uses .active). Keeps the two inputs from fighting each other.

  // --- task 012/013: dismiss results on outside click ---
  // "Inside the search area" = only the input + clear button + results
  // panel cluster. .search-wrap already encloses the input, #q-clear, and
  // #results in the current DOM; #results is listed explicitly as a
  // belt-and-suspenders guard in case the panel is ever moved out of
  // .search-wrap. Task 013 narrowed this from the earlier .searchbar
  // scope: clicks on the <h1> title, or the empty strip of the sticky
  // .searchbar to the right of the input, are now treated as OUTSIDE
  // and dismiss the results panel. Anchor-click navigation on .result
  // rows still works — this listener only flips panel.hidden, it does
  // not preventDefault on the event, so the browser's native
  // <a href="file:///…"> navigation proceeds.
  document.addEventListener('click', function(e) {
    if (panel.hidden) return;
    var tgt = e.target;
    if (tgt && tgt.closest && (tgt.closest('.search-wrap') || tgt.closest('#results'))) return;
    hideResults();
  });

  // Focusing the input (via click OR Tab) re-opens the panel for whatever
  // query is still in the field. Empty query → stays hidden (showResults
  // handles that). Chrome's event order is mousedown → focus → click, so
  // a click on the input fires focus (showResults) BEFORE the document
  // click listener runs — and the document click listener exempts clicks
  // inside .search-wrap/#results anyway, so there is no bounce.
  input.addEventListener('focus', function() {
    showResults();
  });
});
</script>
</body>
</html>
TAIL
} > "$out"

echo "Wrote $out ($(wc -c < "$out") bytes, $grand_total models)"
