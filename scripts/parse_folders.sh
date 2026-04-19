#!/usr/bin/env bash
# parse_folders.sh — emit "<abs-path>\t<recurse-flag>" lines from 3mffolders.md
#
# Reads 3mffolders.md at the repo root and prints one line per folder entry:
#   <absolute-path>\t<recurse-flag>
# where recurse-flag is 1 if the source line ended with "*" (optionally
# preceded by whitespace or a path separator), else 0. Examples that set
# the flag: "C:\foo *", "C:\foo\*", "C:\foo*".
#
# - Skips blank lines and lines beginning with "#" (comments).
# - Trims surrounding whitespace from paths.
# - Warns (stderr) but does not abort when a listed path does not exist.
# - Aborts with exit 1 if 3mffolders.md is missing, empty, or yields
#   zero valid entries.

set -euo pipefail

# Operate on repo root regardless of CWD.
cd "$(dirname "$0")/.."

folders_file="3mffolders.md"

if [[ ! -f "$folders_file" ]]; then
  echo "parse_folders.sh: error: '$folders_file' not found at $(pwd)" >&2
  exit 1
fi

# Count valid entries while emitting them.
entry_count=0

# Read line by line; use IFS= and -r to preserve the line verbatim.
# Note: `|| [[ -n "$line" ]]` handles files without a trailing newline.
while IFS= read -r line || [[ -n "$line" ]]; do
  # Strip a possible trailing CR (Windows line endings).
  line="${line%$'\r'}"

  # Trim leading whitespace.
  line="${line#"${line%%[![:space:]]*}"}"
  # Trim trailing whitespace.
  line="${line%"${line##*[![:space:]]}"}"

  # Skip blank lines.
  [[ -z "$line" ]] && continue
  # Skip comment lines.
  [[ "${line:0:1}" == "#" ]] && continue

  # Detect trailing "*" as the recurse marker. Accept it with or without
  # a preceding separator — any of " *", "\*", "/*", or a bare "*"
  # glued to the path all set the flag. Require at least one char
  # before the "*" so a line of only "*" is not treated as a valid entry.
  flag=0
  if [[ "$line" =~ ^(.+)\*$ ]]; then
    flag=1
    line="${BASH_REMATCH[1]}"
    # Strip a trailing path separator ('\' or '/') exposed by removing '*'.
    line="${line%[\\/]}"
    # Trim any trailing whitespace exposed by stripping the marker.
    line="${line%"${line##*[![:space:]]}"}"
  fi

  # After stripping, the path must be non-empty.
  [[ -z "$line" ]] && continue

  # Warn (but don't abort) if the listed path doesn't exist on disk.
  if [[ ! -d "$line" ]]; then
    echo "parse_folders.sh: warning: listed path does not exist: $line" >&2
  fi

  printf '%s\t%s\n' "$line" "$flag"
  entry_count=$((entry_count + 1))
done < "$folders_file"

if (( entry_count == 0 )); then
  echo "parse_folders.sh: error: '$folders_file' contains zero valid entries" >&2
  exit 1
fi
