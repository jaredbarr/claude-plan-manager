---
description: List, open, search, or archive Claude Code plan files in ~/.claude/plans/
allowed-tools:
  - Bash
  - Read
  - Edit
---

# /plans

User invoked: `/plans $ARGUMENTS`

Plans live in `~/.claude/plans/`. Treat that directory as the source of truth.

Dispatch on `$ARGUMENTS`:

## No args, or `list` (optionally `list N` for a different count, default 20)

Run:

```bash
ls -1t ~/.claude/plans/*.md 2>/dev/null | head -20
```

Render the result as a numbered list (1 = newest), each entry on its own line as:

```
{n}. {filename}    {human-readable mtime}
```

Use `stat` to get mtimes. If no files exist, say so plainly.

## `open N`

Open the Nth most recent plan (1-indexed). Read its contents with the Read tool and display them.

## `search TERM`

Run:

```bash
grep -l -i -- "TERM" ~/.claude/plans/*.md
```

List matching files newest-first with a 1-line snippet of the matched context for each.

## `archive N`

Move the Nth most recent plan into `~/.claude/plans/archive/` (creating the dir if needed). Confirm the move with the new path. Do not delete anything.

## `current`

Show the path to the most recently modified plan only. Useful for piping into other tools.

## `rename-all`

One-shot backfill: rename **every** un-prefixed plan in `~/.claude/plans/` to the `YYYY-MM-DD-HHMM-{slug}.md` convention, using the same logic as the auto-rename hook. Files already matching the prefix are skipped (idempotent).

To run it, locate the plugin's rename script and invoke it with the `all` argument:

```bash
script=$(find ~/.claude/plugins -type f -name rename-plan.sh -path '*plan-manager*' 2>/dev/null | head -1)
[[ -z "$script" ]] && { echo "rename-plan.sh not found in plugin install"; exit 1; }
bash "$script" all
```

Show the script's output verbatim so the user sees each rename. Do not pre-summarise or filter the lines.

## Anything else

Print a short usage hint listing the subcommands above. Do not guess.

---

**Notes for Claude:**
- Never delete plans without explicit user instruction.
- `archive` is a move, not a delete.
- Indices are computed each invocation against the current `ls -t` ordering — they're not stable across sessions.
- This command pairs with the `rename-plan` hook (PostToolUse on ExitPlanMode), which gives plans `YYYY-MM-DD-HHMM-{slug}.md` names.
