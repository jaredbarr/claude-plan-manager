# claude-plan-manager

A small Claude Code plugin that makes the `~/.claude/plans/` folder useful.

Out of the box, plan-mode files get harness-generated slug names like `nested-coalescing-widget.md` — fine in isolation, useless once you have a dozen of them. This plugin:

1. **Renames plans** automatically when you exit plan mode:
   - `YYYY-MM-DD-HHMM-{project}-{title-slug}.md` when the session's `cwd` is inside a git repo (project = the repo's basename)
   - `YYYY-MM-DD-HHMM-{title-slug}.md` otherwise
   The title-slug is derived from the plan's first `# Heading`; the timestamp comes from the file's mtime.
2. **Project copies (opt-in)** — if the session's cwd contains a `.claude/plans/` directory, the renamed plan is also copied there so it lives alongside the code that motivated it.
3. **Adds a `/plans` slash command** for listing, opening, searching, archiving, and backfilling past plans.

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

Examples:

```
# In ~/sites/rc-holly (a git repo)
~/.claude/plans/nested-coalescing-widget.md
                  ↓ ExitPlanMode fires
~/.claude/plans/2026-04-16-1430-rc-holly-platform-hosting-comparison.md

# In ~/Downloads (not a git repo)
~/.claude/plans/witty-orbiting-nova.md
                  ↓ ExitPlanMode fires
~/.claude/plans/2026-04-16-1430-platform-hosting-comparison.md
```

The title-slug comes from the first `# H1` in the plan file (falls back to the original slug if missing). The project name is the basename of `git rev-parse --show-toplevel` from the session cwd, slugified and capped at 30 chars.

### Project copies (opt-in)

To make plans for a given project live alongside its code:

```bash
cd ~/sites/your-project
mkdir -p .claude/plans
```

That's the entire setup. Going forward, every time you `ExitPlanMode` while your session is in this project, the renamed plan will be copied to `<project>/.claude/plans/` in addition to `~/.claude/plans/`. The filename is identical in both locations (so you can correlate them).

Notes:
- Detection is per-session-cwd, not per-file. The hook sees the cwd from the JSON payload it receives on stdin.
- Whether to commit `.claude/plans/` is your call per project — the plugin doesn't touch `.gitignore`.
- It's a snapshot at `ExitPlanMode` time, not a live sync. Edits to the global plan after that don't propagate.
- `rename-all` (backfill) doesn't make project copies — there's no per-file cwd context to use.

### `/plans` command

```
/plans                  # list 20 most recent (alias for `list`)
/plans list 50          # list 50 most recent
/plans open 1           # open the most recent plan
/plans search migration # find plans containing "migration"
/plans archive 5        # move the 5th newest plan to archive/
/plans current          # print path to newest plan
/plans rename-all       # one-shot backfill: rename every un-prefixed plan
```

> Plugin commands in Claude Code are namespaced. Invoke as `/plan-manager:plans …` (or use tab completion).

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
- **Why git toplevel basename for the project name?** It's the cleanest signal that the session is "in a project". Other heuristics (presence of `package.json`, `Gemfile`, etc.) are language-specific and miss new repos. Falling back to no-project when not in a git repo is conservative — better than tagging with a misleading parent directory name.
- **Why no project tag in `rename-all`?** The original session cwd isn't recoverable from the plan file after the fact. Tagging every backfilled plan with the cwd at run-time would be wrong for most of them.

## Compatibility

Tested on:
- macOS (BSD `stat`, `date`)
- Linux (GNU `stat`, `date`)

Requires Claude Code with plugin support.

## License

MIT
