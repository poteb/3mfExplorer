# Narrow Dismiss Containment

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Bug fix to task 012: clicking in the empty strip to the right of the search input (but still inside the sticky top bar) does **not** dismiss the results panel. Clicking below the bar does. User expectation is that both dismiss — "outside the search field" means outside the input/clear-button/results-panel cluster, not outside the whole sticky header.

Root cause: task 012's document-click handler uses `e.target.closest('.searchbar')` to decide "inside vs outside". The `.searchbar` element spans the full viewport width and also contains the `<h1>`, so clicks anywhere in that strip (including the empty area around the title) count as inside.

Fix:
- Narrow the containment check to the actual search cluster. Options:
  - Use the `.search-wrap` element (input + clear button) **and** `#results` — a click is "inside" only if it's in one of those two subtrees. `e.target.closest('.search-wrap') || e.target.closest('#results')`.
  - Or add a dedicated wrapper around input + clear button + results and test that single selector.
- Clicking the `<h1>` title, or the empty space to the right of the input, should now dismiss the results.
- Clicking a result row still navigates (don't break the primary action).
- Everything else from task 012 still holds: `q.value` is preserved, refocusing the input re-shows results, keyboard nav / clear button / Escape unchanged.

Implementation: JS edit inside `scripts/generate_index.sh`. Small change — a selector swap, essentially. Update the comment near the handler to explain the narrower scope.

Done when: clicking anywhere outside the input + clear-button + results-panel triad (including the strip to the right of the input inside the sticky bar, and on the `<h1>`) hides the results; clicking inside any of those three still does not dismiss.

## Notes
- **Selector used**: `e.target.closest('.search-wrap') || e.target.closest('#results')`. In the current DOM `.search-wrap` already encloses the `<input id="q">`, the `<button id="q-clear">`, and the `<div id="results">` (lines 266–272 of `generate_index.sh`), so `.search-wrap` alone would suffice. I included `#results` explicitly as a belt-and-suspenders guard so that if `#results` is ever moved out of `.search-wrap` in a future DOM reorg, the containment check still behaves correctly. This matches the task spec's literal wording ("Use the `.search-wrap` element **and** `#results`") and its intent.
- **Narrowed scope**: the `<h1>3MF Explorer</h1>` and the empty strip to the right of the input (both children of `.searchbar` but NOT of `.search-wrap`) are now treated as OUTSIDE — a click on them triggers `hideResults()`. The earlier `.searchbar` check (task 012) was too broad because `.searchbar` spans the full viewport width.
- **Result-row clicks still navigate**: `.result` rows live inside `#results` which is inside `.search-wrap`, so `tgt.closest('.search-wrap')` returns non-null and the document-click handler early-returns. The listener doesn't `preventDefault`, so the native `<a href="file:///…">` navigation proceeds. Confirmed by reading the DOM layout (lines 266–272 of `generate_index.sh`) and the listener body (lines 427–432 of regenerated `_index.html`).
- **Unchanged**: `#q` focus handler, `clearSearch()`, keydown handler (ArrowUp/Down/Enter/Escape), `#q-clear` click handler, CSS, and all render/debounce logic. Selector swap + comment update only.
- **Comments updated**: the block comment above the handler now explains the narrower scope and why `<h1>`/strip clicks dismiss. Also updated the comment above the `focus` listener (line 439) to say "inside .search-wrap/#results" instead of "inside .searchbar".
- **Verification**:
  - `bash scripts/refresh.sh` → exit 0, `Extracted 101 / 101 thumbnails to ./thumbnails/`, `Wrote _index.html (40593 bytes, 101 models)`.
  - Regenerated `_index.html` grep:
    - Line 430: `if (tgt && tgt.closest && (tgt.closest('.search-wrap') || tgt.closest('#results'))) return;` — the new narrower containment test.
    - No `.searchbar` in the containment test itself; remaining `.searchbar` references in `_index.html` are the CSS selectors (lines 37–39) and two references inside the JS block comment (lines 420, 422) explaining what changed — expected.
    - `function hideResults` / `function showResults` / `function clearSearch` each present once.
    - `addEventListener('keydown'` / `addEventListener('input'` / `addEventListener('focus'` each present once.
    - `ArrowDown|ArrowUp|Escape` — 7 matches (keydown branches + comments), unchanged from task 012.
    - `breadcrumbFor` — 2 matches (definition + call site), unchanged.
    - 101 `class="card"` anchors, 12 `<details` (11 real + 1 in a JS comment, matches task 012's balance) / 11 `</details>`.
- **Browser smoke-test**: not performed. Same `file:///` limitation as tasks 008–012 — Chrome MCP `navigate` prepends `https://` and cross-scheme navigation is blocked. Manual test on the user's own browser remains the one way to exercise the real click/focus path.

## Questions
