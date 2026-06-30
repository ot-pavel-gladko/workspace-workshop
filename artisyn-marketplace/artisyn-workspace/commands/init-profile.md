---
description: Scaffold workspace-profile.yaml from the bundled template (legacy-adoption flow)
argument-hint: ""
allowed-tools: Bash
---

Scaffold a `workspace-profile.yaml` at the current workspace root using the
template bundled with this plugin. Use this when you have an already-cloned
**legacy** workspace (with `workspace.py` and `artisyn-marketplace/` present)
but no `workspace-profile.yaml` yet — `/artisyn-workspace:activate` refuses to
proceed without one.

For a **greenfield** install (no workspace yet) use `/artisyn-workspace:install`,
which generates the profile interactively.

## Scope (intentionally narrow)

This command:

- Creates `workspace-profile.yaml` at the cwd.
- Pre-fills `project.name` and `project.description` from the cwd basename.
- Leaves every other field as a TODO marker — you fill them in by hand.

This command does NOT touch `workspace.py`, `.claude/`, `prompts/`,
`steering-docs/`, or `artisyn-marketplace/`. Hand-curated assets are safe.

Refuses to run if `workspace-profile.yaml` already exists.

## After running this

1. Open `workspace-profile.yaml` and fill the TODOs:
   - List your `repos` (or set `repo_discovery: src_scan` and leave `repos: []`).
   - Toggle the `mcp.*` blocks for the integrations you actually use.
   - Set the `agents.include_*` flags to match the agent files you already have in `.claude/agents/`.
2. Run `/artisyn-workspace:activate` — it verifies the three markers
   (`workspace.py`, `artisyn-marketplace/` (or legacy `aila-marketplace/`), `workspace-profile.yaml`) and
   hydrates `.venv/` and `.claude/settings.local.json`. No other files change.
3. Do **NOT** run `artisyn-workspace bootstrap` immediately afterwards.
   Bootstrap regenerates `workspace.py` from the profile and may drop
   hand-added `Agent(...)` declarations not captured by the profile. That
   step is the deliberate legacy-to-profile migration cut-over.

## Execute

```bash
if [ -f workspace-profile.yaml ]; then
  echo "ERROR: workspace-profile.yaml already exists at $(pwd)."
  echo "       Refusing to overwrite. Edit it by hand, or remove it first."
  exit 1
fi

TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/workspace-profile.yaml.template"
if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: Template not found at $TEMPLATE."
  exit 1
fi

WS_NAME="$(basename "$(pwd)")"
# Strip the optional 'workspace-' prefix if the cwd already includes it.
SHORT_NAME="${WS_NAME#workspace-}"

sed -e "s/workspace-<TODO>/${WS_NAME}/g" "$TEMPLATE" > workspace-profile.yaml

echo "Created workspace-profile.yaml"
echo "  project.name=${WS_NAME}"
echo ""
echo "Next steps:"
echo "  1. Edit workspace-profile.yaml — fill in repos, mcp toggles, agent toggles."
echo "  2. /artisyn-workspace:activate"
echo ""
echo "Do NOT run 'artisyn-workspace bootstrap' until you intend to migrate"
echo "workspace.py to profile-driven regeneration."
```
