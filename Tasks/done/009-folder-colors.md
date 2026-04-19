# Folder Colors

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Add more color to the nested folder sections in `_index.html`. Every `<details>` at the same nesting depth gets the same color; different depths get different colors.

Palette:
- Use **pastel** shades from Google Material Design Colors (https://materialui.co/colors) — e.g. the `100` or `50` tints of hues like Pink, Purple, Indigo, Teal, Green, Amber, Deep Orange. Pick a harmonious sequence that reads well on the existing dark theme.
- Plan for at least 5 depth levels (top-level listed folder = depth 0). If a tree goes deeper than the palette length, cycle.

Where to apply the color:
- Use it consistently across depth levels — pick one treatment that looks clean on the dark theme and stick with it. Good options: a left border stripe on `<details>`, a tinted `<summary>` background, or an accent strip under the summary. Document the choice and the chosen pastel palette in the task notes.
- Keep contrast high enough that `<summary>` text remains readable. Don't touch the card/thumbnail styling — this is about the folder sections, not the items inside them.

Implementation: CSS only, inside `scripts/generate_index.sh`. Either derive depth from existing `data-cat` slashes (`data-cat` already uses `slug/rel/sub/path`) or emit a `data-depth="N"` attribute when rendering each `<details>`. Whichever is simpler.

Done when: regenerating `_index.html` shows visually distinct pastel accents per depth level, same-depth sections share a color, and the existing dark-theme readability is preserved.

## Notes

- **Palette** (Material Design 100 tints, 6 hues):
  - Depth 0 — Pink 100 `#F8BBD0`
  - Depth 1 — Green 100 `#C8E6C9` _(swapped from Purple on user feedback — pastel pink and pastel purple read as too similar adjacent)_
  - Depth 2 — Indigo 100 `#C5CAE9`
  - Depth 3 — Teal 100 `#B2DFDB`
  - Depth 4 — Purple 100 `#E1BEE7` _(moved from depth 1)_
  - Depth 5 — Amber 100 `#FFECB3`
  - Cycles via `depth % 6` for deeper trees. CSS rules emitted for depth 0-10.
- **Treatment chosen: left border stripe** (`border-left: 4px solid <pastel>`). Rationale:
  - The existing dark theme (`#161616` details background, `#eee` summary text) already has strong text contrast. A tinted summary background at low opacity is subtle to the point of being invisible; at higher opacity it washes out the `#eee` text on pastels. A solid-pastel summary with a dark-text override would clash with the card grid inside.
  - A 4px left stripe reads as a clear depth cue (like a folder tab) without touching text contrast or disturbing the card area. It also aligns visually with how nested `<details>` indent.
- **Implementation approach**: emit `data-depth="N"` on each `<details>` (top-level = 0; recurse increments). Generate CSS rules in bash so palette is easy to edit.
- **Depth attribution strategy**: passed `depth` as a 4th arg to `emit_section_recursive` (defaults to 0), incremented on recursion. Flat (non-recursive) sections are always depth 0. Simpler than counting `/` in `data-cat` at runtime.
- **Verification**:
  - `refresh.sh` exit 0: `Extracted 101 / 101 thumbnails`, `Wrote _index.html (35291 bytes, 101 models)`. Count-guard silently passed.
  - 11 `<details>` tags, 11 `</details>` — balanced.
  - 11/11 `<details>` have `data-depth`.
  - 3 top-level listed folders (Space Monkey, Pork 3D, lov3d) all at `data-depth="0"`.
  - 8 Space Monkey subcategories (Animals, Animals with Attitude, Dolls, Fantasy, Greek Mythology, Misc, Patchwork, Xmas) all at `data-depth="1"`.
  - CSS rules for depth 0 through 10 present.
  - 101 cards still present.
  - Existing task-008 searchbar CSS (`.searchbar`, `#results`) and task-005 localStorage `cat-open:` JS untouched.
- **Browser smoke test**: skipped, same `file:///` scheme limitation noted in task 008 (Chrome MCP `navigate` rejects `file:///` URLs). Offline DOM/grep checks as above.

## Questions
