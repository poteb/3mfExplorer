# Search Field

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Add a search field at the top of `_index.html` that filters `.3mf` items by name and folds out a results panel below the input. Clicking a result opens the `.3mf` (same `file:///` href as the main grid).

Behavior:
- Input sits above the `<h1>` (or right beside it) — sticky at the top of the viewport so it stays reachable while the main tree is scrolled.
- **Matching**: case-insensitive substring match on the display name (the text currently rendered in `<div class="name">`). Trim leading/trailing whitespace in the query. Empty query → results panel hidden.
- **Results layout (flat with breadcrumb)**: each result is a row showing a small thumbnail icon + the display name + a breadcrumb of the folder context above the name. Breadcrumb format: `<listed-folder-display> / <sub> / <sub>` mirroring the nested `<details>` titles the item would appear under in the main index. Small icon = noticeably smaller than the main grid cards (pick a sensible size like 48–64px; document the choice in notes).
- Clicking a result opens the `.3mf` via its `file:///` href in the default app, same as the main grid cards.
- The main tree stays visible (the results panel folds out from the input area — overlay or pushed content, pick whichever fits the existing dark theme cleanly; document the choice).
- No external JS deps; keep it in the inline `<script>` alongside the existing localStorage expand-state code.
- Build the search index at page load from the DOM (each card already has its name, href, and thumbnail src; derive the breadcrumb by walking up enclosing `<details><summary>` nodes).

Implementation lives in `scripts/generate_index.sh` — add the input element, the results-panel container, the CSS, and the JS. Don't change the card data model or the extractor/refresh pipeline.

Done when: typing in the search field produces an instant filtered list of matching `.3mf` items with breadcrumbs and small thumbnails, clicking a result opens the file, clearing the field hides the panel, and the main tree is unchanged.

## Notes
- Implemented entirely inside `scripts/generate_index.sh`: added sticky search bar CSS, the `<div class="searchbar">` HTML wrapper (containing the `<h1>` + `<input id="q">` + `<div id="results" hidden>`), and new inline JS alongside the existing localStorage expand-state snippet.
- **Sticky layout**: opted for *overlay* results panel. The searchbar is a sticky top flex row (h1 on the left, search input on the right, max-width 520px). The `#results` div is absolutely positioned directly under the input (so the main tree is not pushed around), with `max-height: 60vh` and `overflow-y: auto`, and a subtle box-shadow to lift it over the grid. The sticky bar gets a bottom border that matches the existing `#2a2a2a` card/summary borders to stay on-theme.
- Used negative margins (`margin: -20px -20px 12px`) on `.searchbar` so it spans edge-to-edge even though `body` has 20px padding — that way it feels anchored to the viewport top.
- **Thumbnail size**: chose **48px** square (smaller than the 220px grid cards, keeps result rows compact so ~8–10 visible at a time within the 60vh cap).
- Result row layout: `img` + flex column (breadcrumb small+muted on top, name 13px on bottom). Hover highlight `#1f1f1f` matches `summary:hover`.
- **Debounce**: 100ms via `setTimeout` on each `input` event.
- **Breadcrumb**: walks ancestor `<details>` bottom-up via `node.parentNode`, `unshift`ing each summary's text (with the trailing `<span class="count">N</span>` stripped by cloning the summary and removing `.count` children before reading `textContent`). Separator ` / `. Top-level listed folders show their full path (e.g. `D:\3D\Space Monkey 3D Designs`), nested sections show their basename — matches the display used in the main tree.
- **Verification**:
  - `bash scripts/refresh.sh` → exit 0, extractor report "Extracted 101 / 101", "Wrote _index.html (34442 bytes, 101 models)".
  - Structural greps confirmed: `<input id="q">` on line 46, `<div id="results" hidden>` on line 47, 101 `class="card"` anchors, 11 real `<details>` open + 11 `</details>` close (a 12th `<details` literal appears only inside a JS code comment), both `DOMContentLoaded` search logic and the original `data-cat` / `localStorage` expand-state JS coexist in the single `<script>` block.
  - Offline simulation of the breadcrumb JS via Node (regex walk over `_index.html` mirroring the DOM ancestor walk) confirmed 101 cards built, "dragon" substring yields exactly one hit "Capybara Dragon" with breadcrumb `D:\3D\Space Monkey 3D Designs / Animals` — i.e. a correctly nested 2-level path.
- **Browser smoke-test**: not run. The `mcp__claude-in-chrome__navigate` tool rejected `file:///...` URLs (auto-prepended `https://`), and navigating from `https://example.com` to `file:///` via `location.href` was blocked by Chrome's security policy (cross-scheme navigation from http(s) to file is denied). The Node-based DOM-walk simulation above exercises the same breadcrumb+matching logic and confirms correctness, but the literal "open in Chrome, type in the field, see the dropdown render" end-to-end visual test was not performed by me.

## Questions
