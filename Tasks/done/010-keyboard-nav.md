# Keyboard Nav for Search Results

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Add keyboard navigation to the search results panel from task 008.

Behavior (while the search input has focus and the results panel is visible):
- **↓ (ArrowDown)**: move the active-row highlight down by one. If nothing is active yet, highlight the first row. If already at the last row, wrap to the first (or stay — pick whichever feels better and document the choice).
- **↑ (ArrowUp)**: move the highlight up by one. Wrap to the last from the first (or stay — same call as ArrowDown, keep them symmetric).
- **Enter**: open the currently highlighted result's `.3mf` (navigate to its `href`). If no row is active but there is at least one result, treat Enter as "open the first result". If there are zero results, Enter is a no-op.
- **Escape**: already clears the input — keep that behavior.

Visual:
- The active row should look clearly distinct from the plain hover state. Pick a subtle accent — a thicker left border, a slightly brighter background, an outline, whatever fits the existing dark theme. Mouse hover keeps working independently; moving the mouse over a row can either update the keyboard-active index or not (pick one and stick with it).
- Scroll the results container so the active row stays in view (`scrollIntoView({block: 'nearest'})`).

Reset rules:
- Typing in the input (changing the query) resets the active index — default to 0 (first result highlighted) OR -1 (no highlight until the user arrows down). Pick 0 so Enter always opens something useful; document the choice.
- Hiding the results panel (empty query) clears the active index.

Implementation: extend the inline `<script>` block in `scripts/generate_index.sh` — the `DOMContentLoaded` handler added in task 008. Don't touch the localStorage expand-state code or the extractor/refresh scripts.

Done when: typing a query, pressing ↓/↑ walks the results with a visible highlight, Enter opens the highlighted `.3mf`, and the existing mouse click + Escape-clear behavior still work.

## Notes
- Implemented entirely inside `scripts/generate_index.sh` — extended the existing inline search `<script>` block from task 008 and added a single CSS rule for `.result.active`. localStorage expand-state JS, folder-color stripe CSS (task 009), card/thumbnail styling, and the search handler itself were left untouched.
- **Wrap vs clamp**: chose **wrap-around** on both ArrowDown and ArrowUp (`(activeIndex + 1) % rows.length` and `(activeIndex - 1 + rows.length) % rows.length`). Rationale: simpler, symmetric, and the task file explicitly listed it as fine.
- **Mouse hover updates active index?**: **No — hover and keyboard-active are independent states**. `.result:hover { background: #1f1f1f; }` is kept (existing subtle hover tint) and `.result.active` is a distinct style. Rationale: mouse-drives-keyboard coupling can feel jumpy (cursor parked over a row hijacks the ↓ walk); keeping them independent lets the two input modes coexist without fighting. Clicking a row still navigates (native `<a href>` behavior), so the mouse path is fully functional.
- **Reset on input**: **reset to 0** when at least one result exists, else `-1`. Applied inside `render()` after the rows are appended so Enter-immediately-after-typing always opens the first hit (matches the task's "Enter always opens something useful" preference).
- **Visual treatment for `.result.active`**: `background: #243140` (a dark desaturated blue, noticeably brighter than `#1f1f1f` hover) plus `box-shadow: inset 3px 0 0 #6cf` (an inset 3px left accent using the same `#6cf` sky-blue that's already used for `#q:focus` and `.card:hover` outline, to stay on-theme). Inset shadow was preferred over `border-left` because the rows already participate in a flex layout with fixed heights; an inset shadow doesn't nudge content or affect layout.
- **Enter handling**: `e.preventDefault()` and `window.location.href = rows[idx].href` — avoids the native form-submit-style side effects on `<input type="search">` and matches the behavior of clicking the `<a class="result">`. Empty-results / hidden-panel / zero-rows paths are explicit no-ops so Enter in an empty field doesn't trap the user.
- **Escape**: preserved the existing clear-and-hide behavior; additionally reset `activeIndex = -1` when Escape fires, so a subsequent query starts fresh.
- **ArrowDown/ArrowUp guards**: `if (panel.hidden) return;` before row lookup, so arrow keys are inert when the panel isn't showing (empty query state). `preventDefault()` is called before the `rows.length === 0` check so the browser doesn't also move the input caret in edge cases.
- **Scroll**: `rows[activeIndex].scrollIntoView({block: 'nearest'})` on both arrows keeps the active row in view within the 60vh-capped scrollable results panel without yanking the surrounding page.
- **Verification**:
  - `bash scripts/refresh.sh` → exit 0, `Extracted 101 / 101 thumbnails`, `Wrote _index.html (37133 bytes, 101 models)`.
  - `grep` of regenerated `_index.html`:
    - `.result.active` CSS rule present (line 47).
    - `keydown` listener on `#q` present (line 341).
    - `activeIndex`, `ArrowDown`, `ArrowUp`, `scrollIntoView({block: 'nearest'})` all present.
    - Existing task-008 search JS (`render`, `breadcrumbFor`, `summaryText`, `input` listener, debounce) still present.
    - Existing task-005 localStorage expand-state JS (`cat-open:` keys, `toggle` listener) still present.
    - 101 `class="card"` anchors — unchanged.
    - `<details` open/close balanced at 11/11 (a 12th `<details` literal appears only inside a JS comment — same as task 008).
    - 11 `details[data-depth=...]` CSS rules preserved from task 009.
- **Browser smoke-test**: **not performed**. Same `file:///` scheme limitation noted in tasks 008 and 009 — Chrome MCP `navigate` auto-prepends `https://` and rejects `file:///` URLs; `location.href` navigation from http(s) to file is blocked by Chrome's cross-scheme policy. Offline grep + logic review serves as verification here. A manual check in the user's own Chrome/Firefox on `D:\git\3mfExplorer\_index.html` would exercise the real keyboard-nav path.

## Questions
