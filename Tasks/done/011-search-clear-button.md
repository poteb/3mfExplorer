# Search Clear Button

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Add a visible "X" clear button inside the search input. Clicking it empties the field, hides the results panel, and returns focus to the input. Pressing **Escape** while the input is focused must do the same (task 008 reported Escape already clears — verify, and if it only clears the text without hiding the panel or resetting state, fix it).

Behavior:
- X button sits inside the right edge of the `<input id="q">` (absolutely positioned on top of the input, or use a wrapper; match the dark theme).
- Visible only when the input has a non-empty value — hidden when empty to avoid visual clutter.
- Click: set `q.value = ''`, dispatch an `input` event (so the existing search handler runs and hides `#results`), refocus `q`, and clear any active keyboard-nav highlight (see task 010 if that's already in).
- Escape key: same effect.
- Don't interfere with typing — the X sits to the right of the caret, doesn't overlap text at typical lengths, and doesn't trigger on Enter.

Styling:
- Minimal: a dim "×" glyph that brightens on hover, same dark-theme palette (e.g. `#888` → `#eee` on hover).
- Keyboard accessible: `<button type="button" aria-label="Clear search">`, not a `<div>`.

Implementation: `scripts/generate_index.sh` only — HTML structure for the button, CSS for positioning, JS hooks in the existing inline `<script>`. Don't disturb the search index, the breadcrumb logic, the folder colors, or the localStorage expand-state code.

Done when: any non-empty query shows an X button; clicking X or pressing Escape clears the field, hides the results panel, and leaves focus in the input ready for a new query.

## Notes
- Implemented entirely in `scripts/generate_index.sh`. HTML, CSS, and JS are all additive alongside the existing search-bar code from tasks 008/009/010 and the localStorage expand-state code from task 005. Nothing from those earlier tasks was modified except the Escape handler (see below).
- **HTML**: the existing `<div class="search-wrap">` wrapper (added in task 008) already had `position: relative`, so no structural change was needed — just inserted `<button type="button" id="q-clear" aria-label="Clear search" hidden>&times;</button>` between the `<input id="q">` and `<div id="results">`. Used `&times;` (×) rather than the literal Unicode character for portability and to match the existing HTML-entity style (e.g. `&amp;` in the helpers).
- **CSS choices**:
  - Added `padding-right: 32px` to `#q` (was `padding: 8px 12px`, now `padding: 8px 32px 8px 12px`) to reserve space for the × button so it never overlaps the caret at typical query lengths.
  - `#q-clear` is absolutely positioned inside `.search-wrap`, right-aligned with `right: 6px`, vertically centered via `top: 50% + translateY(-50%)`. Transparent background, no border, `cursor: pointer`, `font-size: 18px`, `color: #888` → `#eee` on hover (exactly the palette the task file suggested).
  - Added a `:focus-visible` rule with a `2px #6cf` outline (same sky-blue used for `#q:focus` and `.card:hover`) so keyboard focus is obvious in the dark theme.
  - Added `#q-clear[hidden] { display: none; }` so the `hidden` attribute actually hides the button (native `display: none` behavior of the `hidden` attribute works, but being explicit matches `#results[hidden]` already present).
- **JS — shared `clearSearch()` helper**: introduced a single helper inside the existing `DOMContentLoaded` handler. It does: `input.value = ''`, `panel.hidden = true`, `panel.innerHTML = ''`, `activeIndex = -1`, `clearBtn.hidden = true`, `input.focus()`. Both the × click handler and the Escape key handler delegate to it so the two code paths can't drift apart.
  - Deviation from the task spec: the spec suggested dispatching a synthetic `input` event from the click handler and letting the existing search handler hide `#results` / reset `activeIndex`. I chose to call the shared helper directly instead, because the existing `input` handler is debounced (100ms `setTimeout`) and dispatching `input` would leave the panel visible for up to ~100ms before `render('')` tore it down. Calling `clearSearch()` directly makes the UI reset instant. The end-state is identical to what the `input` event would have produced.
- **JS — input-event toggle**: added one line to the existing debounced `input` listener: `if (clearBtn) clearBtn.hidden = input.value.length === 0;` — toggles the × button visibility on every keystroke, untouched by the debounce (the visibility flip needs to be immediate).
- **Escape pre-existing behavior — verified, upgraded**: task 008's notes claim "Escape clears the input"; the code at the time of this task already went further (it cleared the input, hid the panel, cleared innerHTML, and reset activeIndex — added by task 010, not 008). So the functional Escape behavior was already correct in the version I inherited. However, it duplicated the clear logic inline. I **replaced the inline Escape block with `clearSearch()`** so both Escape and × are driven by the same code path. This is a refactor for consistency rather than a behavior fix — the pre-existing Escape behavior was already correct. I also added `input.focus()` via the shared helper; Escape previously didn't explicitly refocus (the input already has focus when Escape fires, so this is a no-op on the Escape path but matters for the × click path).
- **Did NOT disturb**: task 005 localStorage expand-state JS (lines 213–227 of regenerated `_index.html`), task 008 search index / render / debounce, task 009 folder-depth color-stripe CSS (11 `details[data-depth="N"]` rules), task 010 ArrowDown/ArrowUp/Enter keyboard-nav handler. Confirmed by grep below.
- **Verification**:
  - `bash scripts/refresh.sh` → exit 0, `Extracted 101 / 101 thumbnails to ./thumbnails/`, `Wrote _index.html (38209 bytes, 101 models)`.
  - Grep on regenerated `_index.html`:
    - `<button type="button" id="q-clear" aria-label="Clear search" hidden>` present on line 64.
    - `getElementById('q-clear')`, `clearSearch()` function definition, and `clearBtn.addEventListener('click', …)` all present.
    - `clearBtn.hidden = input.value.length === 0;` inside the `input` handler.
    - `if (e.key === 'Escape') { clearSearch(); return; }` inside the `keydown` handler.
    - ArrowDown / ArrowUp / Enter branches still present in the same `keydown` handler (task 010 intact).
    - 101 `class="card"` anchors, `<details` open 12 (11 real + 1 in JS comment) / `</details>` 11 — balanced, unchanged from before.
    - 22 `data-depth=` occurrences (11 CSS rules + 11 on real `<details>` elements — task 009 intact).
    - `cat-open:` localStorage key read + write both present (task 005 intact).
    - `summaryText`, `breadcrumbFor`, `index.push` all present (task 008 intact).
    - `.result.active` CSS still present (task 010 intact).
- **Browser smoke-test**: not performed. Same `file:///` limitation documented in tasks 008/009/010 — Chrome MCP `navigate` auto-prepends `https://` and cross-scheme navigation from http(s) to file is blocked. Grep + code review serves as verification. A manual check in the user's own Chrome/Firefox on `D:\git\3mfExplorer\_index.html` would exercise the real click / focus path.

## Questions
