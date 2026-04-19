# Parse Folders

## Status
done  <!-- todo | in progress | blocked | done -->

## Task
Implement `scripts/parse_folders.sh`. Reads `3mffolders.md` at the repo root and prints one line per folder entry: `<absolute-path>\t<recurse-flag>` (flag is `1` if the line ended with ` *`, else `0`).

Behavior:
- `cd "$(dirname "$0")/.."` so it operates on the repo root regardless of CWD.
- Read `3mffolders.md` line by line.
- Skip blank lines and lines beginning with `#` (comments).
- A trailing ` *` (space + asterisk, optionally with trailing whitespace) sets the recurse flag and is stripped from the path.
- Trim surrounding whitespace from the path.
- If `3mffolders.md` is missing, empty, or contains zero valid entries: print a clear error to stderr and exit 1 (per decision 5 in task 001 — abort, no friendly empty page).
- Warn to stderr (but continue) if a listed path does not exist on disk; downstream scripts can decide whether to skip or fail.

Output format: tab-separated, one entry per line. Consumers read with `while IFS=$'\t' read -r path flag; do …; done`.

Done when: script runs standalone against a populated `3mffolders.md`, prints the expected lines, and exits non-zero with a useful message when the file is empty/missing.

## Notes

### Implementation

- Replaced the stub `scripts/parse_folders.sh` with a full implementation.
- `set -euo pipefail`; `cd "$(dirname "$0")/.."` anchors the script to the repo root so CWD doesn't matter.
- Reads `3mffolders.md` line-by-line with `while IFS= read -r line || [[ -n "$line" ]]; do`, which also handles files without a final newline.
- Strips a trailing `\r` on each line (tolerates CRLF line endings from Windows editors).
- Trims leading and trailing whitespace via parameter expansion.
- Skips blank lines and lines whose first non-whitespace char is `#`.
- Detects trailing ` *` (space + asterisk) with `[[ "$line" =~ ^(.+)[[:space:]]\*$ ]]`; sets the flag to `1`, otherwise `0`. The captured path gets a second trailing-whitespace trim so that `  D:\foo  *  ` → `D:\foo`.
- Warns (stderr) when a listed path does not exist on disk (`[[ ! -d "$line" ]]`) but continues processing.
- Emits `printf '%s\t%s\n' "$line" "$flag"`.
- Counts emitted entries; if zero (empty file, only comments/blank lines, etc.) prints a clear error to stderr and exits 1.
- Missing `3mffolders.md` → distinct error message, exit 1.

### Tests executed

All tests used temporary copies of the script under `/tmp/pf_test*` with a matching `3mffolders.md` sibling, so the real repo file was never touched. All temp dirs were removed after testing.

1. **Populated sample (5 entries: comments, blanks, mixed whitespace, mixed recurse flags, a path with spaces):**
   ```
   /tmp/pf_test/scripts/parse_folders.sh
   ```
   Output (stderr warnings elided for brevity):
   ```
   C:\Users\someone\path_no_recurse	0
   D:\data\recurse_me	1
   D:\another\with_whitespace	1
   C:\tmp\no_flag_indented	0
   D:\3D\Space Monkey 3D Designs	1
   ```
   Exit 0. Whitespace stripped correctly; path containing a space (`Space Monkey 3D Designs`) preserved; `*` correctly detached only when preceded by whitespace.

2. **Missing `3mffolders.md`:**
   ```
   /tmp/pf_test2/scripts/parse_folders.sh
   → parse_folders.sh: error: '3mffolders.md' not found at /tmp/pf_test2
   exit=1
   ```

3. **Empty `3mffolders.md`:**
   ```
   /tmp/pf_test3/scripts/parse_folders.sh
   → parse_folders.sh: error: '3mffolders.md' contains zero valid entries
   exit=1
   ```

4. **Comments-and-blanks-only file:** same error as empty, exit 1. Correct.

5. **Mix of existing + non-existing dirs:**
   ```
   /tmp/pf_test5/actually exists	1
   parse_folders.sh: warning: listed path does not exist: /tmp/pf_test5/does_not_exist
   /tmp/pf_test5/does_not_exist	0
   exit=0
   ```
   Warning goes to stderr; output line still emitted; exit 0. Also verified the consumer pattern `while IFS=$'\t' read -r path flag; do …; done` splits correctly and preserves the space in `actually exists`.

6. **CWD independence:** running `/tmp/pf_test/scripts/parse_folders.sh` from `/tmp` still found the sibling `3mffolders.md` — the `cd "$(dirname "$0")/.."` works as intended.

7. **CRLF line endings:** `printf 'C:\\path *\r\nC:\\plain\r\n'`. Both entries parsed correctly; no stray `\r` left in path output.

8. **No trailing newline:** final single-line file with `C:\one *` and no `\n` → correctly emitted `C:\one\t1`. Exit 0.

### Finding: current `3mffolders.md` uses `\*` (no space) not ` *`

The user's `3mffolders.md` at the repo root currently reads:
```
D:\3D\Space Monkey 3D Designs\*
D:\3D\Pork 3D\*
D:\3D\lov3d\*
```

Per the task spec ("A trailing ` *` (space + asterisk, optionally with trailing whitespace) sets the recurse flag and is stripped from the path"), those lines do **not** match and are treated as literal paths ending in `\*` — so the script warns the path doesn't exist and emits flag `0`. Running the script against the real file today:
```
parse_folders.sh: warning: listed path does not exist: D:\3D\Space Monkey 3D Designs\*
D:\3D\Space Monkey 3D Designs\*	0
parse_folders.sh: warning: listed path does not exist: D:\3D\Pork 3D\*
D:\3D\Pork 3D\*	0
parse_folders.sh: warning: listed path does not exist: D:\3D\lov3d\*
D:\3D\lov3d\*	0
```

The `CLAUDE.md` wording ("A trailing `*` means 'recurse…'") is ambiguous about the separator, but the task spec is explicit about the space. I followed the task spec and left `3mffolders.md` untouched (per the dispatch brief: "Leave `3mffolders.md` as-is (user owns its content).").

If the intent was for `\*` (backslash-star, no space) to also set the recurse flag, the spec and/or the file needs to be reconciled — but that's a separate decision, not blocking this task. Flagged here for visibility.

### Follow-up (post-task): relaxed recurse-marker detection

User chose to relax the parser. Regex changed from `^(.+)[[:space:]]\*$` to `^(.+)\*$`, followed by a trailing-`[\\/]` strip and a trailing-whitespace trim. Now any trailing `*` sets the recurse flag, whether preceded by a space (`path *`), a backslash (`path\*`), a forward slash (`path/*`), or glued to the path (`path*`). Bare path with no `*` still yields flag `0`. Verified against the real `3mffolders.md` — all three entries now emit with flag `1` and no "path does not exist" warnings. Edge-case sweep on a synthetic fixture confirmed all five variants parse as expected and the `missing *` case still warns + emits with flag `1`. `CLAUDE.md`'s existing wording ("A trailing `*` means 'recurse into subfolders'") already matches the relaxed behavior, so no CLAUDE.md edit needed.

## Questions
