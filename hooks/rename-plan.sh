#!/usr/bin/env bash
#
# rename-plan.sh
#
# Modes:
#   (no arg) or "latest" — rename only the most recently modified un-prefixed plan.
#                          Used by the PostToolUse hook on ExitPlanMode. Silent.
#                          Reads the hook JSON payload on stdin to discover the
#                          session's cwd. If cwd is inside a git repo, includes
#                          the repo's basename in the renamed slug. Additionally,
#                          if the session's cwd contains a `.claude/plans/`
#                          directory, copies the renamed file into it (project
#                          copy, opt-in via marker dir presence).
#   "all"                — rename every un-prefixed plan in the directory.
#                          Used by `/plan-manager:plans rename-all`. Prints one
#                          line per rename. No project context (per-file project
#                          isn't recoverable after the fact).
#
# Renames `~/.claude/plans/<slug>.md` to either:
#   ~/.claude/plans/YYYY-MM-DD-HHMM-<project>-<title-slug>.md   (project known)
#   ~/.claude/plans/YYYY-MM-DD-HHMM-<title-slug>.md             (no project)
#
# Timestamp is the file's mtime, title-slug is derived from the first markdown H1.
# Files already matching the YYYY-MM-DD-HHMM- prefix are skipped, so the script
# is idempotent.

set -euo pipefail

PLANS_DIR="${HOME}/.claude/plans"
[[ -d "$PLANS_DIR" ]] || exit 0

mode="${1:-latest}"

# Globals set by read_hook_context and rename_one
HOOK_CWD=""
HOOK_PROJECT=""
LAST_NEW_PATH=""

# Slugify any string: lowercase, runs of non-alphanumerics → single hyphen, trim.
# $1 = string, $2 = max length
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g' \
    | sed -E 's/^-+//; s/-+$//' \
    | cut -c1-"$2" \
    | sed -E 's/-+$//'
}

# Parse the hook JSON payload from stdin (latest mode only) and populate
# HOOK_CWD and HOOK_PROJECT globals. Both stay empty if no payload, no cwd, or
# cwd not in a git repo (in HOOK_PROJECT's case).
read_hook_context() {
  if [ -t 0 ]; then
    return 0
  fi

  local payload toplevel raw
  payload=$(cat)
  [[ -z "$payload" ]] && return 0

  HOOK_CWD=$(printf '%s' "$payload" \
    | python3 -c "import json,sys
try:
    print(json.load(sys.stdin).get('cwd',''))
except Exception:
    pass" 2>/dev/null || true)

  [[ -z "$HOOK_CWD" || ! -d "$HOOK_CWD" ]] && { HOOK_CWD=""; return 0; }

  toplevel=$(cd "$HOOK_CWD" && git rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$toplevel" ]]; then
    raw=$(basename "$toplevel")
    HOOK_PROJECT=$(slugify "$raw" 30)
  fi
}

# $1 = file path, $2 = optional project slug
# On success sets LAST_NEW_PATH to the renamed file. Leaves it empty if the
# file was skipped (already prefixed).
rename_one() {
  local file="$1"
  local project="${2:-}"
  local filename
  filename=$(basename "$file")

  LAST_NEW_PATH=""

  # Skip files that already have the YYYY-MM-DD-HHMM- prefix
  if [[ "$filename" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}- ]]; then
    return 0
  fi

  # Title from first markdown H1, fall back to the original filename slug
  local title
  title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || true)
  [[ -z "$title" ]] && title="${filename%.md}"

  local title_slug
  title_slug=$(slugify "$title" 60)
  [[ -z "$title_slug" ]] && title_slug="plan"

  local full_slug
  if [[ -n "$project" ]]; then
    full_slug="${project}-${title_slug}"
  else
    full_slug="$title_slug"
  fi

  # Timestamp from the file's mtime
  local ts mtime
  if [[ "$(uname)" == "Darwin" ]]; then
    ts=$(stat -f "%Sm" -t "%Y-%m-%d-%H%M" "$file")
  else
    mtime=$(stat -c "%Y" "$file")
    ts=$(date -d "@$mtime" +"%Y-%m-%d-%H%M")
  fi

  local new_path="${PLANS_DIR}/${ts}-${full_slug}.md"

  # Avoid clobbering an existing file
  if [[ -e "$new_path" && "$new_path" != "$file" ]]; then
    local i=2
    while [[ -e "${PLANS_DIR}/${ts}-${full_slug}-${i}.md" ]]; do
      ((i++))
    done
    new_path="${PLANS_DIR}/${ts}-${full_slug}-${i}.md"
  fi

  mv "$file" "$new_path"
  LAST_NEW_PATH="$new_path"
  echo "${filename} -> $(basename "$new_path")"
}

# Copy the resolved plan path into the project's .claude/plans/ directory if
# the marker exists. Best-effort; failures are silent so the hook never errors.
copy_to_project() {
  local source="$1"
  [[ -z "$source" || -z "$HOOK_CWD" ]] && return 0
  local project_plans_dir="${HOOK_CWD}/.claude/plans"
  [[ -d "$project_plans_dir" ]] || return 0
  cp "$source" "$project_plans_dir/" 2>/dev/null || true
}

shopt -s nullglob
candidates=("$PLANS_DIR"/*.md)
(( ${#candidates[@]} > 0 )) || exit 0

case "$mode" in
  all)
    for f in "${candidates[@]}"; do
      rename_one "$f" ""
    done
    echo "Done. Scanned ${#candidates[@]} file(s) in $PLANS_DIR."
    ;;
  latest|"")
    read_hook_context

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

    rename_one "$latest" "$HOOK_PROJECT" > /dev/null

    # Copy whatever the resolved file is (renamed or already-prefixed) to the
    # project's .claude/plans/ if the marker dir exists.
    copy_to_project "${LAST_NEW_PATH:-$latest}"
    ;;
  *)
    echo "Unknown mode: $mode (expected 'latest' or 'all')" >&2
    exit 2
    ;;
esac
