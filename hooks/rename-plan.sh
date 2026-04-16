#!/usr/bin/env bash
#
# rename-plan.sh — fired by PostToolUse on ExitPlanMode.
#
# Finds the most recently modified .md in ~/.claude/plans/ and renames it to
# YYYY-MM-DD-HHMM-{slug-of-first-heading}.md, using the file's mtime for the
# timestamp. Skips files that already match the date-prefixed pattern so
# repeated ExitPlanMode calls on the same plan don't accumulate prefixes.

set -euo pipefail

PLANS_DIR="${HOME}/.claude/plans"
[[ -d "$PLANS_DIR" ]] || exit 0

shopt -s nullglob
candidates=("$PLANS_DIR"/*.md)
(( ${#candidates[@]} > 0 )) || exit 0

# Newest by mtime
latest=""
latest_mtime=0
for f in "${candidates[@]}"; do
  if [[ "$(uname)" == "Darwin" ]]; then
    m=$(stat -f "%m" "$f")
  else
    m=$(stat -c "%Y" "$f")
  fi
  if (( m > latest_mtime )); then
    latest_mtime=$m
    latest=$f
  fi
done
[[ -n "$latest" ]] || exit 0

filename=$(basename "$latest")

# Skip if already prefixed: YYYY-MM-DD-HHMM-...
if [[ "$filename" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}- ]]; then
  exit 0
fi

# Pull the first markdown H1 as the title
title=$(grep -m1 '^# ' "$latest" 2>/dev/null | sed 's/^# //' || true)
[[ -z "$title" ]] && title="${filename%.md}"

# Slugify: lowercase, runs of non-alphanumerics → single hyphen, trim, cap at 60 chars
slug=$(printf '%s' "$title" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g' \
  | sed -E 's/^-+//; s/-+$//' \
  | cut -c1-60 \
  | sed -E 's/-+$//')
[[ -z "$slug" ]] && slug="plan"

# Format the file's mtime as YYYY-MM-DD-HHMM
if [[ "$(uname)" == "Darwin" ]]; then
  ts=$(stat -f "%Sm" -t "%Y-%m-%d-%H%M" "$latest")
else
  ts=$(date -d "@$latest_mtime" +"%Y-%m-%d-%H%M")
fi

new_name="${ts}-${slug}.md"
new_path="${PLANS_DIR}/${new_name}"

# Avoid clobbering an existing file
if [[ -e "$new_path" && "$new_path" != "$latest" ]]; then
  i=2
  while [[ -e "${PLANS_DIR}/${ts}-${slug}-${i}.md" ]]; do
    ((i++))
  done
  new_path="${PLANS_DIR}/${ts}-${slug}-${i}.md"
fi

mv "$latest" "$new_path"
