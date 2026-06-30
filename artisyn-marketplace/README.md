# Artisyn Claude marketplace

Internal Claude Code marketplace for Artisyn Delivery Workspace tooling. Hosts the
`artisyn-workspace` plugin, which adds slash commands for installing,
activating, updating, listing skills, scaffolding a workspace profile, and
tracking setup progress — all without leaving Claude Code.

Starting with **v0.4.0** of the Artisyn platform, this marketplace ships
**inside every workspace** (`<workspace>/artisyn-marketplace/`, formerly
`<workspace>/aila-marketplace/`) and is
auto-registered via `<workspace>/.claude/settings.json` (`extraKnownMarketplaces`
+ `enabledPlugins`). No per-machine `/plugin marketplace add ...` step.

## What's in here

```
.claude-plugin/
  marketplace.json                # marketplace catalogue (one plugin: artisyn-workspace)
artisyn-workspace/                # the plugin itself
  .claude-plugin/
    plugin.json                   # plugin manifest (commands list)
  commands/
    install.md                    # /artisyn-workspace:install
    activate.md                   # /artisyn-workspace:activate
    init-profile.md               # /artisyn-workspace:init-profile
    update.md                     # /artisyn-workspace:update
    skills.md                     # /artisyn-workspace:skills
    status.md                     # /artisyn-workspace:status
    help.md                       # /artisyn-workspace:help
  templates/
    workspace-profile.yaml.template  # scaffold used by /artisyn-workspace:init-profile
  scripts/
    install-from-confluence.sh    # mac/linux bootstrap shim
    install-from-confluence.ps1   # windows bootstrap shim
```

## Use it

When a workspace has been bootstrapped, `<workspace>/.claude/settings.json`
already declares this directory as a marketplace and enables the plugin.
Open Claude Code in the workspace; on first launch you'll get a one-time
trust prompt — accept it, then:

```
/artisyn-workspace:install
```

After the first `/artisyn-workspace:install`, the `artisyn-workspace` CLI is
installed via `uv tool install` and the workspace is provisioned.
Subsequent operations use the CLI directly:

| Slash command | What it does |
| --- | --- |
| `/artisyn-workspace:install` | Create a NEW workspace (greenfield): fetch the current `artisyn-stable` wheels and bootstrap it |
| `/artisyn-workspace:activate` | Hydrate an already-cloned workspace on this machine (`.venv` + `settings.local.json`) |
| `/artisyn-workspace:init-profile` | Scaffold a `workspace-profile.yaml` for a legacy workspace (adoption flow) |
| `/artisyn-workspace:update` | Pull the latest `artisyn-stable` wheels and refresh the workspace |
| `/artisyn-workspace:skills [list\|search\|add\|remove\|doctor]` | Browse the Artisyn skill catalog and install / remove specific skills into `.claude/skills/` |
| `/artisyn-workspace:status` | 15-phase setup-progress checklist with `NEXT` call-out |
| `/artisyn-workspace:help [<role>]` | Colored recommended workflow for a role (lead, ba, pm, code, devops, design, domain) |

## Prerequisites

Before running `/artisyn-workspace:install`, set in your shell:

```bash
export ARTISYN_CONFLUENCE_TOKEN=<your Confluence personal access token>
# Optional overrides (defaults shown):
export ARTISYN_CONFLUENCE_URL=https://conf.dataart.com
export ARTISYN_CONFLUENCE_SPACE=SRD
```

## How it works

1. The plugin's `/artisyn-workspace:install` command checks for `artisyn-workspace` on PATH.
2. If absent, it runs the bundled `install-from-confluence.sh` shim, which
   pulls the latest `artisyn_catalog_schema` wheel from a Confluence release
   page (resolved via the `artisyn-stable` label or an explicit version)
   and installs it via `uv tool install`.
3. With the CLI in place, the shim chains `artisyn-workspace install`, which
   downloads the remaining wheels, sets up a `.venv` inside the workspace,
   and runs the bootstrap questionnaire.

## Legacy adoption — generating `workspace-profile.yaml`

`workspace-profile.yaml` at the workspace root is required by
`/artisyn-workspace:activate` (and used by `artisyn-workspace bootstrap`). For a
legacy workspace that doesn't have one yet:

1. `/artisyn-workspace:init-profile` — scaffolds a starter profile from the
   bundled template (`artisyn-workspace/templates/workspace-profile.yaml.template`).
   Pre-fills `project.name` from the cwd basename. Everything else is TODO.
2. Edit the file by hand — list your repos (or set `repo_discovery: src_scan`),
   toggle the MCP integrations you actually use, pick which standard agents
   (BA / DevOps / Design / Domain) you want.
3. `/artisyn-workspace:activate` — verifies the three markers and hydrates
   `.venv/` + `.claude/settings.local.json`. No other files change.

**Do NOT run `artisyn-workspace bootstrap` immediately afterwards.** Bootstrap
regenerates `workspace.py` from the profile and may drop hand-added
`Agent(...)` declarations not captured by the profile. It is the deliberate
legacy-to-profile migration step and should be done with intent.

## Versioning

`plugin.json` and `marketplace.json` versions are bumped in lockstep with
the Artisyn release they target. The plugin itself is forward-compatible: it
pins nothing — the bootstrap shim picks the current `artisyn-stable` if no
version is supplied to `/artisyn-workspace:install`.
