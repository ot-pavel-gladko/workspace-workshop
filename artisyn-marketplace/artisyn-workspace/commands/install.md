---
description: Create a NEW Artisyn Delivery Workspace in this project (greenfield). For an already-cloned workspace use /artisyn-workspace:activate.
argument-hint: "[version] [--here] [--name NAME] [--skills skill-a,skill-b]"
allowed-tools: Bash
---

Create a fresh Artisyn Delivery Workspace in the current project, fetching wheels from
Confluence. **Greenfield only** — if `workspace.py` and `artisyn-marketplace/`
(or legacy `aila-marketplace/`) already exist here (someone else committed the
workspace to git), run
`/artisyn-workspace:activate` instead.

## What this does

1. Refuses to run if an Artisyn Delivery Workspace is already present in the cwd
   (points the user at `/artisyn-workspace:activate`).
2. Checks whether `artisyn-workspace` is already on PATH. If not, runs the
   bundled bootstrap (`install-from-confluence.sh`) to pull the
   `artisyn-catalog-schema` wheel from Confluence and `uv tool install` it.
3. Runs `artisyn-workspace install $ARGUMENTS`, which fetches the rest of the
   wheels, sets up a fresh `.venv`, and chains into `artisyn-workspace bootstrap`.

## Prerequisites

- `$ARTISYN_CONFLUENCE_TOKEN` (or the legacy `$AILA_CONFLUENCE_TOKEN` /
  `$CONFLUENCE_PERSONAL_TOKEN`) must be set in the shell environment.
- `uv` will be installed automatically if missing.

## Arguments

| Argument | Description |
|---|---|
| `[version]` | Pin a specific release (e.g. `0.12.0`). Omit for the latest `artisyn-stable`. |
| `--here` | Install into the current directory instead of a new named workspace dir. |
| `--name NAME` | Override the workspace directory name. |
| `--skills skill-a,skill-b,...` | Comma-separated list of extra skill names to install on top of the baseline `DEFAULT_SKILLS`. Each name is validated against the aggregated skill catalog **before any file is created or modified**. If any name is not found in the catalog the command aborts non-zero, prints the unrecognised names, and suggests `skills list` / `skills search` to find valid ones. If the catalog is unreachable at install time (e.g. offline environment) and `--skills` is supplied, the install also aborts — run without `--skills` to bootstrap offline, then add skills later with `aila-workspace skills add <name>`. Validated skills are persisted to `workspace-profile.yaml` under `extra_skills:` so teammates who clone and run `generate` get the same set with no additional flags. |

## Execute

### Step 0 — Refuse if a workspace is already present

```bash
if [ -f workspace.py ] && { [ -d artisyn-marketplace ] || [ -d aila-marketplace ]; }; then
  echo "ERROR: An Artisyn Delivery Workspace is already present at $(pwd)."
  echo "       This /artisyn-workspace:install command creates a NEW workspace."
  echo "       To hydrate the existing one on this machine, run:"
  echo "         /artisyn-workspace:activate"
  exit 1
fi
```

If this exits non-zero, stop and surface the message to the user — do not
run the remaining steps.

### Step 1 — Bootstrap the CLI (only runs if `artisyn-workspace` is not on PATH)

```bash
if ! command -v artisyn-workspace >/dev/null 2>&1 && ! command -v aila-workspace >/dev/null 2>&1; then
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-from-confluence.sh" --no-chain
    export PATH="$HOME/.local/bin:$PATH"
fi
```

### Step 2 — Install into a workspace

```bash
# Translate a bare positional version (e.g. `0.12.0`) into `--version 0.12.0`
# so the CLI's argparse picks it up. Tokens that already start with `-` or
# `--` are passed through untouched.
ARTISYN_ARGS="$ARGUMENTS"
case "$ARTISYN_ARGS" in
  "" | -*) ;;
  *) ARTISYN_ARGS="--version $ARTISYN_ARGS" ;;
esac
artisyn-workspace install $ARTISYN_ARGS
```

Run the steps in order via the Bash tool.

After the run, report:

- the `=== Install complete ===` summary block (workspace path, version),
- any per-file `regenerated` / `preserved` lines from the chained bootstrap.
