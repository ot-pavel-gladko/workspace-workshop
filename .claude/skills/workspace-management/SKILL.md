---
name: workspace-management
description: |
  Manage Kiro workspaces end-to-end: define workspace in Python, generate local dev structure, convert to Artisyn catalog format, and publish to cloud provider. Covers the full lifecycle from KiroWorkspace definition through catalog generation and AWS publishing.

  Use when creating new Kiro workspaces, adding agents to workspaces, generating catalog output, or publishing workspace resources to Artisyn catalog.

  Triggers: "Create workspace", "Generate catalog", "Publish workspace", "Add agent to workspace", "Workspace management".

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: workspace-management
  level: "201"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-03-19"
  tags: [workspace, kiro, catalog, agents, publishing, generation, aila]
---

# Workspace Management

Manage Kiro workspaces end-to-end: define workspace in Python, generate local dev structure, convert to Artisyn catalog format, and publish to cloud provider.

## Quick Start

**What it does:** Full lifecycle management for Kiro CLI workspaces with Artisyn catalog integration

**When to use:**
- "Create a new Kiro workspace"
- "Generate catalog from workspace"
- "Publish workspace to catalog"
- "Add agent to workspace"

**Inputs:**
- Workspace definition (workspace.py)
- Agent definitions (KiroAgent)
- Skill references (KiroCatalogSkill)

**Outputs:**
- Local Kiro dev structure (agents/, prompts/, .kiro/)
- Catalog workspace (catalog_workspace/skills/)
- Published resources in Artisyn catalog (AWS S3/DynamoDB)

## Workflow

### Step 1: Define Workspace

Create `workspace.py` with KiroWorkspace definition:

```python
from aila_catalog_schema import KiroWorkspace, KiroAgent, KiroCatalogSkill, KiroPrompt

workspace = KiroWorkspace(
    name="my-workspace",
    description="My workspace description",
    agents=[
        KiroAgent(
            name="my-agent",
            description="Agent purpose",
            prompt=KiroWorkspace.prompt_ref("my-prompt.md"),
            tools=["code", "execute_bash", "fs_read", "fs_write"],
            steering=".kiro/steering",
        ),
    ],
    prompts=[
        KiroPrompt(name="my-prompt.md", description="Agent system prompt"),
    ],
    skills=[
        KiroCatalogSkill(name="generic-sdlc", description="SDLC process", provider_name="skill-library-aila"),
    ],
)

if __name__ == "__main__":
    workspace.run_cli()
```

### Step 2: Generate Local Dev Structure

```bash
python3 workspace.py generate
```

Produces:
- `agents/{name}.json` — agent JSON configs
- `.kiro/agents/{name}.json` — symlinks for Kiro discovery
- `prompts/wsg-agent-guide.md` — auto-generated agent guide
- `.kiro/skills/wsg-skill-guide.md` — auto-generated skill guide
- `.kiro/steering/` — steering symlinks
- `.kiro/settings/mcp.json` — MCP server config
- `README_WORKSPACE.md`, `WORKSPACE_SELFTEST.md`, `WORKSPACE_BOOTSTRAP.md`

### Step 3: Validate

```bash
python3 workspace.py validate
```

### Step 4: Generate Catalog

Create `generate_catalog.py` with CatalogConverter:

```python
from aila_catalog_schema.kiro_converter import CatalogConverter
from workspace import workspace

converter = CatalogConverter(workspace)
# CLI: python3 generate_catalog.py generate|validate|publish
```

```bash
python3 generate_catalog.py generate   # -> catalog_workspace/skills/
python3 generate_catalog.py validate   # -> verify catalog output
```

### Step 5: Publish

```bash
python3 generate_catalog.py publish    # -> AWS S3 via skill-sdk-aila
```

## Key Types

| Type | Purpose |
|---|---|
| `KiroWorkspace` | Complete workspace definition + generation |
| `KiroAgent` | Agent config -> agents/{name}.json |
| `KiroCatalogSkill` | Skill reference for .kiro/skills/ |
| `KiroPrompt` | Prompt file reference |
| `KiroExternalLink` | Symlink to external repo |
| `KiroSettings` | MCP/LSP configuration |
| `CatalogConverter` | Kiro -> catalog conversion |

## Path Resolution Rules

| Field | Resolves From | Example |
|---|---|---|
| `prompt` | Agent JSON dir (.kiro/agents/) | `file://../../prompts/expert.md` |
| `resources` | Workspace root | `file://external-links/repo/KNOW.md` |
| `steering` | Workspace root | `.kiro/steering` |

## Prompt Naming Convention

- `wsg-*` — workspace-generated (auto, do not edit)
- `wsc-*` — catalog template prompts
- Other — project-specific prompts

## Catalog Output Structure

```
catalog_workspace/
  .catalogignore
  skills/
    aila-knowledge/artifacts/{name}/KNOW.md
    declarative-agent-management/artifacts/{agent}/AGENT.json
    workspace-management/artifacts/{workspace}/WORKSPACE.json
```

## RESOURCE_CONFIG Mapping

The catalog converter uses RESOURCE_CONFIG (skill-sdk-aila) to map files to skills:
- `AGENT.json` -> `declarative-agent-management` skill
- `KNOW.md` -> `aila-knowledge` skill
- `WORKSPACE.json` -> `workspace-management` skill
- `PROMPT.md` -> `aila-prompts` skill

## Dependencies

```
aila-catalog-schema (types + converter + Kiro generation)
    ^
skill-sdk-aila (providers + publish + RESOURCE_CONFIG)
    ^
workspace repos (workspace.py + generate_catalog.py)
```
