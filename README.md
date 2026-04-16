# claude-plan-manager

A small Claude Code plugin that makes the `~/.claude/plans/` folder useful.

Out of the box, plan-mode files get harness-generated slug names like `nested-coalescing-widget.md` — fine in isolation, useless once you have a dozen of them. This plugin:

1. **Renames plans** to `YYYY-MM-DD-HHMM-{slug}.md` automatically when you exit plan mode, where the slug is derived from the plan's first `# Heading` and the timestamp comes from the file's mtime.
2. **Adds a `/plans` slash command** for listing, opening, searching, and archiving past plans.

## Install

### From this repo (self-hosted marketplace)

```
/plugin marketplace add jaredbarr/claude-plan-manager
/plugin install plan-manager@jared-plugins
```

### Local dev install

```
/plugin marketplace add ~/sites/claude-plan-manager
/plugin install plan-manager@jared-plugins
```

## Usage

### Renaming (automatic)

Nothing to do. Enter plan mode, build a plan, call `ExitPlanMode`. The hook fires and renames the file. Skips files that already match the date prefix, so it's idempotent.

Example:

```
~/.claude/plans/nested-coalescing-widget.md
                  ↓ ExitPlanMode fires
~/.claude/plans/2026-04-16-1430-platform-hosting-comparison.md
```

The slug comes from the first `# H1` in the plan file. If there isn't one, it falls back to the original slug.

### `/plans` command

```
/plans                  # list 20 most recent (alias for `list`)
/plans list 50          # list 50 most recent
/plans open 1           # open the most recent plan
/plans search migration # find plans containing "migration"
/plans archive 5        # move the 5th newest plan to archive/
/plans current          # print path to newest plan
```

Indices are 1-based and reflect the current `ls -t` ordering at invocation time.

## Files

```
.claude-plugin/
  plugin.json          plugin metadata
  marketplace.json     self-hosted marketplace pointer
hooks/
  hooks.json           PostToolUse hook on ExitPlanMode
  rename-plan.sh       the rename script (bash, macOS + Linux)
commands/
  plans.md             /plans slash command
README.md
```

## Design notes

- **Why mtime instead of "now" for the timestamp?** So that if a hook fires late or you re-run it on an older file, the prefix still matches when the plan was authored, not when it was renamed.
- **Why skip already-prefixed files?** Re-entering plan mode for the same task fires `ExitPlanMode` again. Without the skip you'd accumulate prefixes.
- **Why a hook on `ExitPlanMode` and not on `Write`?** Plans are often edited (via `Edit`) multiple times during a single planning turn. Renaming on every write would be noisy and could happen mid-edit.

## Compatibility

Tested on:
- macOS (BSD `stat`, `date`)
- Linux (GNU `stat`, `date`)

Requires Claude Code with plugin support.

## License

MIT
