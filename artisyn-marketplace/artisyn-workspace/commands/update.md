---
description: Update an existing Artisyn Delivery Workspace to the current stable (or pinned) release
argument-hint: "[version] [--here] [--workspace-path PATH]"
allowed-tools: Bash
---

Refresh the wheels in an existing Artisyn Delivery Workspace from Confluence, preserving
user files (`workspace.py`, `prompts/`, `.claude/`, `steering-docs/`, etc.).

## Scope (intentionally narrow, v0.12.2+)

`update` touches only:

- `.venv/` — recreated, wheels reinstalled.
- `.artisyn/cache/` — vendored release refreshed (committed copy of wheels +
  manifest so PAT-less teammates can `/artisyn-workspace:activate` without
  Confluence).
- `artisyn-marketplace/` — slash-command templates refreshed (hash-tracked,
  preserves hand-edits).
- `.claude/skill_catalog.json` — regenerated to reflect newly-shipped
  skills.
- The `artisyn-workspace` CLI on PATH — self-updated via `uv tool install`.

`update` does **not** run `workspace.py generate`. That means
`.claude/agents/`, `.claude/skills/`, `.claude/commands/`,
`.claude/rules/`, `CLAUDE.md`, and `README_WORKSPACE.md` are left alone.
If new agents / skills / commands shipped in this release and you want
them rendered into the workspace, run `artisyn-workspace bootstrap` from the
workspace directory afterwards. The narrow update lets you adopt new wheels without
recompiling hand-edited workspace artifacts.

## Execute

```bash
# Translate a bare positional version (e.g. `0.12.0`) into `--version 0.12.0`
# so the CLI's argparse picks it up. Tokens that already start with `-` or
# `--` are passed through untouched.
ARTISYN_ARGS="$ARGUMENTS"
case "$ARTISYN_ARGS" in
  "" | -*) ;;
  *) ARTISYN_ARGS="--version $ARTISYN_ARGS" ;;
esac
artisyn-workspace update $ARTISYN_ARGS
```

If `artisyn-workspace` is not on PATH, run `/artisyn-workspace:install` first.

After the run, report:

- the `=== Update complete ===` summary block (workspace path, version),
- the `CLI: refreshed (uv tool)` line if present,
- the tail-line hint about running `workspace.py generate` /
  `artisyn-workspace bootstrap` to regenerate agent artifacts. Surface
  this verbatim — the user is in control of when generation happens.
